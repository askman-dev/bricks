# API Quick Reference

## Base URL
- Development: `http://localhost:3000`
- Production: Configure based on deployment

## Authentication Flow

### 1. Initiate OAuth
```
GET /api/auth/github?return_to=<https_url>
```
Redirects to GitHub for authorization.

`return_to` must be an allowed HTTPS URL. Preview deployments are accepted when
the host matches `bricks-<alnum>-askman-dev.vercel.app`.

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
- `GET /api/auth/github` - Start GitHub OAuth (optional `return_to` query)
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

### Unified LLM API (AI protocol-compatible)
All require `Authorization: Bearer <token>` header and use user's default `llm`
configuration unless `provider` is explicitly passed.

- `POST /api/llm/chat` - Single response generation
- `POST /api/llm/chat/stream` - SSE streaming response

Example request:

```json
{
  "provider": "anthropic",
  "model": "claude-sonnet-4-5",
  "messages": [
    { "role": "system", "content": "You are concise." },
    { "role": "user", "content": "Hello" }
  ],
  "temperature": 0.2,
  "maxTokens": 512
}
```

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
