package handlers

import (
	"errors"
	"io"
	"net"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/services"
	"github.com/hospital/nms-backend/pkg/logger"
)

// SitesHandler serves the websites view: sites by name with logo, per device and
// per site, and the catalog the hospital keeps.
type SitesHandler struct {
	service       *services.SitesService
	auditRepo     *repository.AuditRepository
	retentionDays int
}

func NewSitesHandler(service *services.SitesService, auditRepo *repository.AuditRepository, retentionDays int) *SitesHandler {
	return &SitesHandler{service: service, auditRepo: auditRepo, retentionDays: retentionDays}
}

func (h *SitesHandler) orgID(c *gin.Context) (uuid.UUID, bool) {
	id, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization", "error_code": "VALIDATION_ERROR"})
		return uuid.Nil, false
	}
	return id, true
}

func hoursParam(c *gin.Context) int {
	n, err := strconv.Atoi(c.DefaultQuery("hours", "24"))
	if err != nil || n < 1 {
		return 24
	}
	return n
}

func fail(c *gin.Context, status int, code, message string) {
	c.JSON(status, gin.H{"success": false, "message": message, "error_code": code})
}

// Overview ranks the sites asked for in the last `hours` (default 24).
func (h *SitesHandler) Overview(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	out, err := h.service.Overview(c.Request.Context(), orgID, hoursParam(c), c.Query("background") == "1", h.retentionDays)
	if err != nil {
		logger.Warn("Sites overview failed", "error", err)
		fail(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Could not read the recorded sites")
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": out, "message": "Sites retrieved"})
}

// Device lists the sites one device (MAC or IP) asked for. Looking at one person's
// browsing is written to the audit log.
func (h *SitesHandler) Device(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	out, err := h.service.DeviceSites(c.Request.Context(), orgID, c.Param("key"), hoursParam(c), c.Query("background") == "1")
	if err != nil {
		fail(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Could not read the recorded sites")
		return
	}
	h.audit(c, orgID, "security.device_sites_viewed", out.Name, out.MAC)
	c.JSON(http.StatusOK, gin.H{"success": true, "data": out, "message": "Device sites retrieved"})
}

// Site lists the devices that asked for one site.
func (h *SitesHandler) Site(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	out, err := h.service.SiteDevices(c.Request.Context(), orgID, c.Param("domain"), hoursParam(c))
	if err != nil {
		fail(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	h.audit(c, orgID, "security.site_devices_viewed", out.Site.Name, "")
	c.JSON(http.StatusOK, gin.H{"success": true, "data": out, "message": "Site devices retrieved"})
}

// Logo returns the image of a named site. The logo is public information about a
// company, not about a person, so it is not audited.
func (h *SitesHandler) Logo(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	data, contentType, err := h.service.Logo(c.Request.Context(), orgID, c.Param("domain"))
	if err != nil {
		c.Status(http.StatusNotFound)
		return
	}
	c.Header("Cache-Control", "private, max-age=3600")
	c.Header("X-Content-Type-Options", "nosniff")
	c.Data(http.StatusOK, contentType, data)
}

type catalogBody struct {
	Name     string   `json:"name"`
	Category string   `json:"category"`
	Domains  []string `json:"domains"`
	// FetchLogo asks the server to download the logo from the site right away.
	FetchLogo bool `json:"fetch_logo"`
}

func (h *SitesHandler) catalogError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, repository.ErrNotFound):
		fail(c, http.StatusNotFound, "NOT_FOUND", "Site not found")
	case errors.Is(err, services.ErrSiteExists):
		fail(c, http.StatusConflict, "ALREADY_EXISTS", err.Error())
	case errors.Is(err, services.ErrNotAnImage):
		fail(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
	default:
		fail(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
	}
}

// answerWithLogo fetches the logo for a new or changed entry when asked. A failure
// to fetch is not a failure to save: the entry is returned with the reason.
func (h *SitesHandler) answerWithLogo(c *gin.Context, orgID uuid.UUID, entry repository.CatalogEntry, fetch bool, status int, message string) {
	logoError := ""
	if fetch {
		updated, err := h.service.FetchLogo(c.Request.Context(), orgID, entry.ID)
		if err != nil {
			logoError = err.Error()
		} else {
			entry = updated
		}
	}
	c.JSON(status, gin.H{"success": true, "data": entry, "logo_error": logoError, "message": message})
}

func (h *SitesHandler) Create(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	var body catalogBody
	if err := c.ShouldBindJSON(&body); err != nil {
		fail(c, http.StatusBadRequest, "VALIDATION_ERROR", "Send a name, a category and at least one domain")
		return
	}
	entry, err := h.service.Create(c.Request.Context(), orgID, services.CatalogInput{Name: body.Name, Category: body.Category, Domains: body.Domains})
	if err != nil {
		h.catalogError(c, err)
		return
	}
	h.audit(c, orgID, "security.site_named", entry.Name, "")
	h.answerWithLogo(c, orgID, entry, body.FetchLogo, http.StatusCreated, "Site added")
}

// Adopt names a site seen in the recording; built-in sites need only the domain.
func (h *SitesHandler) Adopt(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	var body struct {
		Domain   string `json:"domain"`
		Name     string `json:"name"`
		Category string `json:"category"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || body.Domain == "" {
		fail(c, http.StatusBadRequest, "VALIDATION_ERROR", "Send the domain")
		return
	}
	entry, err := h.service.Adopt(c.Request.Context(), orgID, body.Domain, body.Name, body.Category)
	if err != nil {
		h.catalogError(c, err)
		return
	}
	h.audit(c, orgID, "security.site_named", entry.Name, "")
	h.answerWithLogo(c, orgID, entry, true, http.StatusCreated, "Site added")
}

func (h *SitesHandler) Update(c *gin.Context) {
	orgID, ok := h.orgID(c)
	id, err := parseUUID(c.Param("id"))
	if !ok {
		return
	}
	if err != nil {
		fail(c, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid id")
		return
	}
	var body catalogBody
	if err := c.ShouldBindJSON(&body); err != nil {
		fail(c, http.StatusBadRequest, "VALIDATION_ERROR", "Send a name, a category and at least one domain")
		return
	}
	entry, err := h.service.Update(c.Request.Context(), orgID, id, services.CatalogInput{Name: body.Name, Category: body.Category, Domains: body.Domains})
	if err != nil {
		h.catalogError(c, err)
		return
	}
	h.audit(c, orgID, "security.site_renamed", entry.Name, "")
	h.answerWithLogo(c, orgID, entry, body.FetchLogo, http.StatusOK, "Site updated")
}

func (h *SitesHandler) Delete(c *gin.Context) {
	orgID, ok := h.orgID(c)
	id, err := parseUUID(c.Param("id"))
	if !ok {
		return
	}
	if err != nil {
		fail(c, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid id")
		return
	}
	if err := h.service.Delete(c.Request.Context(), orgID, id); err != nil {
		h.catalogError(c, err)
		return
	}
	h.audit(c, orgID, "security.site_removed", id.String(), "")
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Site removed"})
}

// FetchLogo downloads the logo from the site itself.
func (h *SitesHandler) FetchLogo(c *gin.Context) {
	orgID, ok := h.orgID(c)
	id, err := parseUUID(c.Param("id"))
	if !ok {
		return
	}
	if err != nil {
		fail(c, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid id")
		return
	}
	var body struct {
		LogoURL string `json:"logo_url"`
	}
	_ = c.ShouldBindJSON(&body) // the body is optional
	entry, err := h.service.FetchLogoFrom(c.Request.Context(), orgID, id, body.LogoURL)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			h.catalogError(c, err)
			return
		}
		fail(c, http.StatusBadGateway, "LOGO_FETCH_FAILED", "Could not get the logo from the site: "+err.Error())
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": entry, "message": "Logo saved"})
}

// UploadLogo stores an image sent in the request body (at most 256 KB).
func (h *SitesHandler) UploadLogo(c *gin.Context) {
	orgID, ok := h.orgID(c)
	id, err := parseUUID(c.Param("id"))
	if !ok {
		return
	}
	if err != nil {
		fail(c, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid id")
		return
	}
	data, err := io.ReadAll(http.MaxBytesReader(c.Writer, c.Request.Body, 256<<10+1))
	if err != nil {
		fail(c, http.StatusRequestEntityTooLarge, "VALIDATION_ERROR", services.ErrNotAnImage.Error())
		return
	}
	entry, err := h.service.SetLogo(c.Request.Context(), orgID, id, data)
	if err != nil {
		h.catalogError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": entry, "message": "Logo saved"})
}

func (h *SitesHandler) ClearLogo(c *gin.Context) {
	orgID, ok := h.orgID(c)
	id, err := parseUUID(c.Param("id"))
	if !ok {
		return
	}
	if err != nil {
		fail(c, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid id")
		return
	}
	if err := h.service.ClearLogo(c.Request.Context(), orgID, id); err != nil {
		h.catalogError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Logo removed"})
}

// audit records who looked at or changed what; a failure to record is logged only.
func (h *SitesHandler) audit(c *gin.Context, orgID uuid.UUID, action, name, detail string) {
	userID, err := parseUUID(c.GetString("user_id"))
	if err != nil {
		return
	}
	entry := &models.AuditLog{
		ID: uuid.New(), OrganizationID: orgID, Action: action, EntityType: "security", EntityName: &name,
		PerformedBy: &userID, IsSuccess: true,
	}
	if ip := net.ParseIP(c.ClientIP()); ip != nil {
		entry.IPAddress = &ip
	}
	if detail != "" {
		entry.Description = &detail
	}
	if err := h.auditRepo.Create(c.Request.Context(), entry); err != nil {
		logger.Debug("Audit entry not stored", "action", action, "error", err)
	}
}
