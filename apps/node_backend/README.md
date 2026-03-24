# Bricks Backend Service

Backend service for the Bricks chat-first creation app. Provides user authentication and API configuration management.

## Features

- **User Authentication**
  - GitHub OAuth login
  - JWT-based session management
  - Extensible design for future providers (Google, Email, etc.)
  - Self-managed user IDs (UUID), independent of OAuth providers

- **API Configuration Management**
  - Store multiple model provider configurations (Gemini, Anthropic, OpenAI, etc.)
  - Encrypted storage for sensitive data (API keys)
  - Support for default provider selection
  - Per-user configuration isolation

## Tech Stack

- **Runtime**: Node.js ≥20.19.0
- **Framework**: Express
- **Database**: PostgreSQL (Vercel Postgres/Neon compatible)
- **Authentication**: JWT + OAuth
- **Encryption**: AES-256-GCM

## Project Structure

```
apps/node_backend/
├─ src/
│  ├─ index.ts                    # Express server setup
│  ├─ routes/
│  │  ├─ auth.ts                  # Authentication routes
│  │  └─ config.ts                # API configuration routes
│  ├─ db/
│  │  ├─ index.ts                 # Database connection
│  │  ├─ migrate.ts               # Migration runner
│  │  └─ migrations/
│  │     ├─ 001_create_users.sql
│  │     ├─ 002_create_oauth_connections.sql
│  │     └─ 003_create_api_configs.sql
│  ├─ services/
│  │  ├─ userService.ts           # User management logic
│  │  └─ configService.ts         # API config with encryption
│  └─ middleware/
│     └─ auth.ts                  # JWT authentication middleware
├─ package.json
├─ tsconfig.json
├─ .env.example
└─ README.md
```

## Getting Started

### Prerequisites

- Node.js ≥20.19.0
- PostgreSQL database (local or Vercel Postgres)
- GitHub OAuth app (for authentication)

### Installation

1. Install dependencies:

```bash
cd apps/node_backend
npm install
```

2. Set up environment variables:

```bash
cp .env.example .env
```

Edit `.env` and configure:

- `DATABASE_URL`: PostgreSQL connection string
- `JWT_SECRET`: Secure random string (≥32 characters)
- `ENCRYPTION_KEY`: Secure random string (≥32 characters)
- `GITHUB_CLIENT_ID`: Your GitHub OAuth app client ID
- `GITHUB_CLIENT_SECRET`: Your GitHub OAuth app client secret
- `GITHUB_CALLBACK_URL`: OAuth callback URL (default: `http://localhost:3000/api/auth/github/callback`)

**Generate secure secrets:**

```bash
# Generate JWT_SECRET
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# Generate ENCRYPTION_KEY
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

3. Set up GitHub OAuth:

   - Go to https://github.com/settings/developers
   - Create a new OAuth App
   - Set Authorization callback URL to your `GITHUB_CALLBACK_URL`
   - Copy Client ID and Client Secret to `.env`

### Database Setup

The application will automatically run migrations on startup if `AUTO_MIGRATE=true` in `.env`.

To run migrations manually:

```bash
npm run migrate
```

### Development

Start the development server with hot reload:

```bash
npm run dev
```

The server will start on `http://localhost:3000` (or the port specified in `.env`).

### Production

Build the TypeScript code:

```bash
npm run build
```

Start the production server:

```bash
npm start
```

### Type Checking

Run TypeScript type checking:

```bash
npm run type-check
```

### Linting

Run ESLint:

```bash
npm run lint
```

## API Documentation

### Base URL

- Development: `http://localhost:3000`
- Production: Configure based on deployment

### Authentication Endpoints

#### `GET /api/auth/github`

Initiates GitHub OAuth flow. Redirects to GitHub for authentication.

#### `GET /api/auth/github/callback`

GitHub OAuth callback. Exchanges authorization code for JWT token.

**Query Parameters:**
- `code` (string): GitHub authorization code

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "created_at": "2026-03-24T05:00:00.000Z"
  }
}
```

#### `GET /api/auth/me`

Get current user information.

**Headers:**
- `Authorization: Bearer <token>`

**Response:**
```json
{
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "created_at": "2026-03-24T05:00:00.000Z",
    "updated_at": "2026-03-24T05:00:00.000Z"
  },
  "oauth_connections": [
    {
      "provider": "github",
      "provider_user_id": "12345678",
      "created_at": "2026-03-24T05:00:00.000Z"
    }
  ]
}
```

#### `DELETE /api/auth/me`

Delete current user account (cascades to OAuth connections and API configs).

**Headers:**
- `Authorization: Bearer <token>`

**Response:**
```json
{
  "message": "User deleted successfully"
}
```

### API Configuration Endpoints

All configuration endpoints require authentication via `Authorization: Bearer <token>` header.

#### `POST /api/config`

Create a new API configuration.

**Request Body:**
```json
{
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
}
```

**Response:** Returns the created configuration (with `api_key` decrypted for the response).

#### `GET /api/config`

Get all API configurations for the current user.

**Query Parameters:**
- `category` (optional): Filter by category (e.g., `llm`)

**Response:**
```json
[
  {
    "id": "650e8400-e29b-41d4-a716-446655440001",
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "category": "llm",
    "provider": "anthropic",
    "config": {
      "endpoint": "https://api.anthropic.com",
      "api_key": "sk-ant-...",
      "model_preferences": {
        "default_model": "claude-3-sonnet-20240229"
      }
    },
    "is_default": true,
    "created_at": "2026-03-24T05:00:00.000Z",
    "updated_at": "2026-03-24T05:00:00.000Z"
  }
]
```

#### `GET /api/config/:id`

Get a specific API configuration.

**Response:** Returns the configuration object.

#### `PUT /api/config/:id`

Update an API configuration.

**Request Body:** Same as POST, but all fields are optional.

**Response:** Returns the updated configuration.

#### `DELETE /api/config/:id`

Delete an API configuration.

**Response:**
```json
{
  "message": "Configuration deleted successfully"
}
```

### Health Check

#### `GET /health`

Check if the server is running.

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2026-03-24T05:00:00.000Z"
}
```

## Database Schema

### `users` table

Stores user accounts with self-managed UUIDs.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| created_at | TIMESTAMP | Account creation time |
| updated_at | TIMESTAMP | Last update time |

### `oauth_connections` table

Links OAuth provider accounts to users.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| user_id | UUID | Foreign key to users |
| provider | VARCHAR(50) | OAuth provider (e.g., 'github') |
| provider_user_id | VARCHAR(255) | Provider's user ID |
| access_token | TEXT | OAuth access token (nullable) |
| refresh_token | TEXT | OAuth refresh token (nullable) |
| expires_at | TIMESTAMP | Token expiration (nullable) |
| created_at | TIMESTAMP | Connection creation time |

### `api_configs` table

Stores user API configurations with encrypted sensitive data.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| user_id | UUID | Foreign key to users |
| category | VARCHAR(50) | Config category (e.g., 'llm') |
| provider | VARCHAR(50) | Provider name (e.g., 'anthropic') |
| config | JSONB | Configuration data (api_key encrypted) |
| is_default | BOOLEAN | Whether this is the default config for category |
| created_at | TIMESTAMP | Config creation time |
| updated_at | TIMESTAMP | Last update time |

## Security Features

### Encryption

API keys and other sensitive data in `api_configs.config` are encrypted using AES-256-GCM:

- **Algorithm**: AES-256-GCM
- **Key derivation**: SHA-256 hash of `ENCRYPTION_KEY`
- **Authenticated encryption**: Ensures data integrity
- **Unique IV per encryption**: Prevents pattern analysis

### JWT Authentication

- **Algorithm**: HS256
- **Expiration**: 7 days
- **Payload**: User ID only (minimal data)

### Rate Limiting

- **Window**: 15 minutes
- **Max requests**: 100 per IP
- **Scope**: All `/api/*` endpoints

### Security Headers

Helmet.js provides security headers including:
- Content Security Policy
- X-Frame-Options
- X-Content-Type-Options
- Strict-Transport-Security (HSTS)

## Deployment

### Vercel (Serverless)

1. Install Vercel CLI:

```bash
npm install -g vercel
```

2. Create `vercel.json`:

```json
{
  "version": 2,
  "builds": [
    {
      "src": "src/index.ts",
      "use": "@vercel/node"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "src/index.ts"
    }
  ],
  "env": {
    "NODE_ENV": "production"
  }
}
```

3. Deploy:

```bash
vercel --prod
```

4. Configure environment variables in Vercel dashboard.

### Docker

Create `Dockerfile`:

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

EXPOSE 3000

CMD ["npm", "start"]
```

Build and run:

```bash
docker build -t bricks-backend .
docker run -p 3000:3000 --env-file .env bricks-backend
```

### Environment Variables (Production)

Required environment variables for production deployment:

- `NODE_ENV=production`
- `DATABASE_URL`: PostgreSQL connection string
- `JWT_SECRET`: Secure secret for JWT signing
- `ENCRYPTION_KEY`: Secure key for API key encryption
- `GITHUB_CLIENT_ID`: GitHub OAuth client ID
- `GITHUB_CLIENT_SECRET`: GitHub OAuth client secret
- `GITHUB_CALLBACK_URL`: Production callback URL
- `CORS_ORIGIN`: Your frontend URL (e.g., `https://app.bricks.dev`)
- `PORT`: (Optional) Server port (default: 3000)
- `AUTO_MIGRATE`: (Optional) Auto-run migrations (default: true)

## Testing

### Manual Testing

1. Start the server:

```bash
npm run dev
```

2. Test health endpoint:

```bash
curl http://localhost:3000/health
```

3. Test GitHub OAuth:

- Visit `http://localhost:3000/api/auth/github` in your browser
- Complete GitHub authorization
- Copy the returned JWT token

4. Test authenticated endpoints:

```bash
# Get user info
curl -H "Authorization: Bearer <token>" http://localhost:3000/api/auth/me

# Create API config
curl -X POST \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "category": "llm",
    "provider": "anthropic",
    "config": {
      "api_key": "sk-test-123",
      "endpoint": "https://api.anthropic.com"
    },
    "is_default": true
  }' \
  http://localhost:3000/api/config

# Get configs
curl -H "Authorization: Bearer <token>" http://localhost:3000/api/config
```

## Troubleshooting

### Database Connection Issues

- Verify `DATABASE_URL` is correct
- Check PostgreSQL is running
- Ensure database exists
- Check network connectivity

### Migration Issues

- Run migrations manually: `npm run migrate`
- Check migration logs for errors
- Verify database permissions

### OAuth Issues

- Verify GitHub OAuth app configuration
- Check `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET`
- Ensure `GITHUB_CALLBACK_URL` matches OAuth app settings
- Check that callback URL is accessible

### Encryption Issues

- Verify `ENCRYPTION_KEY` is set and consistent
- Don't change `ENCRYPTION_KEY` after encrypting data (will break decryption)
- If key is lost, encrypted data cannot be recovered

## License

MIT
