package security

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
)

type Claims struct {
	UserID uuid.UUID `json:"user_id"`
	Role   string    `json:"role"`
	OrgID  uuid.UUID `json:"org_id"`
	jwt.RegisteredClaims
}

type JWTManager struct {
	accessSecret  []byte
	refreshSecret []byte
	accessExpiry  time.Duration
	refreshExpiry time.Duration
	issuer        string
}

func NewJWTManager(cfg *config.Config) *JWTManager {
	return &JWTManager{
		accessSecret:  []byte(cfg.JWTAccessSecret),
		refreshSecret: []byte(cfg.JWTRefreshSecret),
		accessExpiry:  cfg.JWTAccessExpiry,
		refreshExpiry: cfg.JWTRefreshExpiry,
		issuer:        cfg.JWTIssuer,
	}
}

func (m *JWTManager) GenerateAccessToken(userID, orgID uuid.UUID, role string) (string, error) {
	claims := &Claims{
		UserID: userID,
		Role:   role,
		OrgID:  orgID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(m.accessExpiry)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
			Issuer:    m.issuer,
			Subject:   userID.String(),
			ID:        uuid.New().String(),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(m.accessSecret)
}

func (m *JWTManager) GenerateRefreshToken(userID uuid.UUID) (string, error) {
	claims := &Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(m.refreshExpiry)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
			Issuer:    m.issuer,
			Subject:   userID.String(),
			ID:        uuid.New().String(),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(m.refreshSecret)
}

func (m *JWTManager) ValidateAccessToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return m.accessSecret, nil
	})

	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid token")
	}

	return claims, nil
}

func (m *JWTManager) ValidateRefreshToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return m.refreshSecret, nil
	})

	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid refresh token")
	}

	return claims, nil
}

func (m *JWTManager) HashToken(token string) string {
	hash := sha256.Sum256([]byte(token))
	return hex.EncodeToString(hash[:])
}
