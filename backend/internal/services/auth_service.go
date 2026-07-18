package services

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"net"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/security"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrInvalidCredentials = errors.New("invalid username or password")
	ErrAccountLocked      = errors.New("account is locked")
	ErrAccountInactive    = errors.New("account is inactive")
	ErrInvalidToken       = errors.New("invalid or expired token")
	ErrUserNotFound       = errors.New("user not found")
	ErrSessionExpired     = errors.New("session expired")
	ErrPasswordReused     = errors.New("password was used recently")
)

type AuthService struct {
	userRepo       *repository.UserRepository
	sessionRepo    *repository.SessionRepository
	jwtManager     *security.JWTManager
	cfg            *config.Config
}

func NewAuthService(userRepo *repository.UserRepository, sessionRepo *repository.SessionRepository, jwtManager *security.JWTManager, cfg *config.Config) *AuthService {
	return &AuthService{
		userRepo:    userRepo,
		sessionRepo: sessionRepo,
		jwtManager:  jwtManager,
		cfg:         cfg,
	}
}

type LoginResponse struct {
	AccessToken  string       `json:"access_token"`
	RefreshToken string       `json:"refresh_token"`
	TokenType    string       `json:"token_type"`
	ExpiresIn    int          `json:"expires_in"`
	User         *models.User `json:"user"`
}

func (s *AuthService) Login(ctx context.Context, username, password, ip, userAgent string) (*LoginResponse, error) {
	user, err := s.userRepo.GetByUsername(ctx, username)
	if err != nil {
		user, err = s.userRepo.GetByEmail(ctx, username)
		if err != nil {
			return nil, ErrInvalidCredentials
		}
	}

	if !user.IsActive {
		return nil, ErrAccountInactive
	}

	if user.IsLocked {
		if user.LockedUntil != nil && user.LockedUntil.After(time.Now()) {
			return nil, ErrAccountLocked
		}
		user.IsLocked = false
		user.LockedUntil = nil
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		s.userRepo.IncrementFailedAttempts(ctx, user.ID)
		if user.FailedLoginAttempts+1 >= s.cfg.RateLimitAuthRequests {
			s.userRepo.LockAccount(ctx, user.ID, 15*time.Minute)
		}
		return nil, ErrInvalidCredentials
	}

	accessToken, err := s.jwtManager.GenerateAccessToken(user.ID, user.OrganizationID, user.Role)
	if err != nil {
		return nil, err
	}

	refreshToken, err := s.jwtManager.GenerateRefreshToken(user.ID)
	if err != nil {
		return nil, err
	}

	s.userRepo.UpdateLastLogin(ctx, user.ID, ip)

	session := &models.UserSession{
		UserID:           user.ID,
		TokenHash:        s.jwtManager.HashToken(accessToken),
		RefreshTokenHash: s.jwtManager.HashToken(refreshToken),
		IPAddress:        parseIP(ip),
		UserAgent:        &userAgent,
		ExpiresAt:        time.Now().Add(s.cfg.JWTRefreshExpiry),
	}
	s.sessionRepo.Create(ctx, session)

	accessExpiry := int(s.cfg.JWTAccessExpiry.Seconds())

	return &LoginResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    accessExpiry,
		User:         user.Sanitize(),
	}, nil
}

func (s *AuthService) RefreshToken(ctx context.Context, refreshToken, userAgent string) (*LoginResponse, error) {
	claims, err := s.jwtManager.ValidateRefreshToken(refreshToken)
	if err != nil {
		return nil, ErrInvalidToken
	}

	userID, err := uuid.Parse(claims.Subject)
	if err != nil {
		return nil, ErrInvalidToken
	}

	tokenHash := s.jwtManager.HashToken(refreshToken)
	session, err := s.sessionRepo.GetByRefreshTokenHash(ctx, tokenHash)
	if err != nil || session.IsRevoked || session.ExpiresAt.Before(time.Now()) {
		return nil, ErrSessionExpired
	}

	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, ErrUserNotFound
	}

	if !user.IsActive {
		return nil, ErrAccountInactive
	}

	accessToken, err := s.jwtManager.GenerateAccessToken(user.ID, user.OrganizationID, user.Role)
	if err != nil {
		return nil, err
	}

	newRefreshToken, err := s.jwtManager.GenerateRefreshToken(user.ID)
	if err != nil {
		return nil, err
	}

	s.sessionRepo.Revoke(ctx, session.ID)
	newSession := &models.UserSession{
		UserID:           user.ID,
		TokenHash:        s.jwtManager.HashToken(accessToken),
		RefreshTokenHash: s.jwtManager.HashToken(newRefreshToken),
		IPAddress:        session.IPAddress,
		UserAgent:        session.UserAgent,
		ExpiresAt:        time.Now().Add(s.cfg.JWTRefreshExpiry),
	}
	s.sessionRepo.Create(ctx, newSession)

	return &LoginResponse{
		AccessToken:  accessToken,
		RefreshToken: newRefreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    int(s.cfg.JWTAccessExpiry.Seconds()),
		User:         user.Sanitize(),
	}, nil
}

func (s *AuthService) Logout(ctx context.Context, accessToken string) error {
	tokenHash := s.jwtManager.HashToken(accessToken)
	session, err := s.sessionRepo.GetByTokenHash(ctx, tokenHash)
	if err == nil {
		return s.sessionRepo.Revoke(ctx, session.ID)
	}
	return nil
}

func (s *AuthService) ValidateToken(tokenString string) (*security.Claims, error) {
	return s.jwtManager.ValidateAccessToken(tokenString)
}

func (s *AuthService) ListSessions(ctx context.Context, userID uuid.UUID) ([]models.UserSession, error) {
	return s.sessionRepo.ListByUser(ctx, userID)
}

func (s *AuthService) RevokeSession(ctx context.Context, userID, sessionID uuid.UUID) error {
	return s.sessionRepo.Revoke(ctx, sessionID)
}

func (s *AuthService) RevokeAllSessions(ctx context.Context, userID uuid.UUID) error {
	return s.sessionRepo.RevokeAllByUser(ctx, userID)
}

func (s *AuthService) ForgotPassword(ctx context.Context, email string) error {
	user, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil {
		return nil
	}

	tokenBytes := make([]byte, 32)
	rand.Read(tokenBytes)
	token := hex.EncodeToString(tokenBytes)

	expiresAt := time.Now().Add(15 * time.Minute)
	s.userRepo.SetPasswordResetToken(ctx, user.ID, token, expiresAt)

	return nil
}

func (s *AuthService) ResetPassword(ctx context.Context, token, newPassword string) error {
	user, err := s.userRepo.GetByPasswordResetToken(ctx, token)
	if err != nil {
		return ErrInvalidToken
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	if err := s.userRepo.UpdatePassword(ctx, user.ID, string(hash)); err != nil {
		return err
	}

	s.userRepo.ClearPasswordResetToken(ctx, user.ID)
	s.sessionRepo.RevokeAllByUser(ctx, user.ID)
	return nil
}

func parseIP(ip string) *net.IP {
	parsed := net.ParseIP(ip)
	if parsed == nil {
		return nil
	}
	return &parsed
}
