# API Architecture - Hospital NMS

## Technology Stack
- **Framework:** Go (Gin v1.10+)
- **API Style:** RESTful with JSON responses
- **Authentication:** JWT (Access + Refresh tokens)
- **Real-time:** WebSocket
- **API Versioning:** URL-based (/api/v1/)

## Base URL
```
Development: http://localhost:8080/api/v1
Staging:     https://staging-api.hospital-nms.com/api/v1
Production:  https://api.hospital-nms.com/api/v1
```

## Standard Response Envelope
```json
{
  "success": true,
  "data": { ... },
  "message": "Operation completed successfully",
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "total_pages": 8
  },
  "errors": null
}
```

## Error Response
```json
{
  "success": false,
  "data": null,
  "message": "Validation failed",
  "meta": null,
  "errors": {
    "email": ["Email is already registered"],
    "password": ["Password must be at least 8 characters"]
  },
  "error_code": "VALIDATION_ERROR",
  "correlation_id": "abc123-def456"
}
```

## Authentication

### POST /api/v1/auth/login
Login with username/password, returns JWT tokens.

### POST /api/v1/auth/refresh
Refresh access token using refresh token.

### POST /api/v1/auth/logout
Invalidate current refresh token.

### GET /api/v1/auth/me
Get current authenticated user profile.

### POST /api/v1/auth/forgot-password
Send password reset email.

### POST /api/v1/auth/reset-password
Reset password with token.

## Devices

### GET /api/v1/devices
List all devices with pagination, filtering, and search.

**Query Parameters:**
- `page` (int, default: 1)
- `limit` (int, default: 20, max: 100)
- `search` (string) - Search name, IP, MAC, hostname
- `status` (string) - Filter by status
- `type` (string) - Filter by device type
- `department` (string) - Filter by department
- `sort_by` (string) - Field to sort by
- `ascending` (bool, default: true)

### GET /api/v1/devices/:id
Get device details.

### POST /api/v1/devices
Create new device.

### PUT /api/v1/devices/:id
Update device.

### DELETE /api/v1/devices/:id
Delete device.

### GET /api/v1/devices/:id/interfaces
Get device interfaces.

### GET /api/v1/devices/:id/metrics
Get device metrics.

## Alerts

### GET /api/v1/alerts
List alerts with filtering.

### GET /api/v1/alerts/:id
Get alert details.

### POST /api/v1/alerts/:id/acknowledge
Acknowledge alert.

### POST /api/v1/alerts/:id/resolve
Resolve alert with notes.

## Network Scans

### GET /api/v1/scans
List scan history.

### POST /api/v1/scans
Start new scan.

### GET /api/v1/scans/:id
Get scan status.

### GET /api/v1/scans/:id/devices
Get devices discovered in scan.

### POST /api/v1/scans/:id/cancel
Cancel running scan.

## Audit Logs

### GET /api/v1/audit-logs
List audit logs with filtering.

### GET /api/v1/audit-logs/export
Export audit logs (CSV/JSON/PDF).

## Dashboard

### GET /api/v1/dashboard/summary
Get dashboard summary statistics.

## WebSocket Endpoints

### WS /ws/alerts
Real-time alert notifications.

### WS /ws/metrics
Real-time device metrics stream.

### WS /ws/discovery
Real-time network discovery progress.

## Rate Limiting
- **Standard:** 100 requests/minute per user
- **Auth endpoints:** 10 requests/minute per IP
- **Burst:** 20 requests in 10 seconds

## HTTP Status Codes
| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 409 | Conflict |
| 422 | Validation Error |
| 429 | Rate Limit Exceeded |
| 500 | Internal Server Error |
| 503 | Service Unavailable |

## Security Headers
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- X-XSS-Protection: 1; mode=block
- Strict-Transport-Security: max-age=31536000; includeSubDomains
- Content-Security-Policy: default-src 'self'
- Cache-Control: no-store
- X-Correlation-ID: <uuid>
