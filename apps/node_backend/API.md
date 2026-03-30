# API Quick Reference

## Base URL
- Development: `http://localhost:3000`
- Production: Configure based on deployment

## Authentication Flow

### 1. Initiate OAuth
```
GET /api/auth/github
```
Redirects to GitHub for authorization.

### 2. Handle Callback
```
GET /api/auth/github/callback?code=<auth_code>
```
Returns JWT token:
```json
{
  "token": "eyJhbGci...",
  "user": { "id": "uuid", "created_at": "timestamp" }
}
```

### 3. Use Token
Include in all authenticated requests:
```
Authorization: Bearer <token>
```

## Endpoints

### Authentication
- `GET /api/auth/github` - Start GitHub OAuth
- `GET /api/auth/github/callback` - OAuth callback
- `GET /api/auth/me` - Get current user (requires auth)
- `DELETE /api/auth/me` - Delete account (requires auth)

### API Configurations
All require `Authorization: Bearer <token>` header.

- `POST /api/config` - Create configuration
- `GET /api/config` - List configurations (optional ?category=llm)
- `GET /api/config/:id` - Get single configuration
- `PUT /api/config/:id` - Update configuration
- `DELETE /api/config/:id` - Delete configuration

### Health Check
- `GET /api/health` - Service health status

## Example: Create API Configuration

```bash
curl -X POST http://localhost:3000/api/config \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "category": "llm",
    "provider": "anthropic",
    "config": {
      "endpoint": "https://api.anthropic.com",
      "api_key": "sk-ant-...",
      "model_preferences": {
        "default_model": "claude-3-sonnet-20240229"
      }
    },
    "is_default": true
  }'
```

## Security Features
- JWT authentication (7-day expiration)
- API keys encrypted with AES-256-GCM
- Rate limiting: 100 requests per 15 minutes per IP
- CORS protection
- Helmet security headers

## Database
PostgreSQL with three tables:
- `users` - User accounts
- `oauth_connections` - OAuth provider links
- `api_configs` - API configurations (encrypted)

For detailed documentation, see [README.md](README.md).
