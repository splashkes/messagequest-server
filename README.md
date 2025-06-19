# MessageQuest Server

Backend server for the MessageQuest immersive role-play messaging app.

## Architecture Decision

Since PocketBase only supports SQLite and DigitalOcean App Platform doesn't provide persistent storage, we're using **Supabase** for our backend:

- ✅ PostgreSQL database (persistent)
- ✅ Real-time subscriptions (WebSockets)
- ✅ Authentication (Email + Apple Sign In)
- ✅ Row Level Security
- ✅ Edge Functions for custom logic
- ✅ Built-in connection pooling

## Quick Start

### Option 1: Supabase Cloud (Recommended)

1. Create a project at [supabase.com](https://supabase.com)
2. Run the migrations in `supabase/migrations/`
3. Deploy Edge Functions from `supabase/functions/`
4. Update your iOS app with the Supabase URL and anon key

### Option 2: Self-hosted Supabase on DigitalOcean

1. Copy `app.yaml.example` to `app.yaml`
2. Update all the environment variables
3. Deploy with: `doctl apps create --spec app.yaml`

### Option 3: Custom Backend on DigitalOcean

Use the `custom-backend/` directory for a pure Go + PostgreSQL solution.

## Features

- User authentication (Email/Password + Sign in with Apple)
- Character management with real-time availability
- Chat messaging with typing indicators
- Push notifications (APNs)
- AI-powered response suggestions
- Character objective tracking

## Environment Variables

See `.env.example` for required configuration.