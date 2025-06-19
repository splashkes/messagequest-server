# DigitalOcean App Platform Deployment Guide

This guide explains how to deploy the MessageQuest server to DigitalOcean App Platform.

## Prerequisites

1. A DigitalOcean account
2. The `doctl` CLI tool installed and authenticated
3. A Supabase project for the database and auth

## Environment Variables

You'll need to set these environment variables in your DigitalOcean app:

### Required Secrets
- `POSTGRES_PASSWORD` - Database password
- `JWT_SECRET` - JWT secret for authentication
- `ANON_KEY` - Supabase anonymous key
- `SERVICE_ROLE_KEY` - Supabase service role key
- `APNS_KEY_ID` - Apple Push Notification Service key ID
- `APNS_TEAM_ID` - Your Apple Developer Team ID
- `APNS_PRIVATE_KEY` - APNS authentication key (.p8 file contents)
- `OPENAI_API_KEY` - OpenAI API key for AI responses

### Automatic Variables
- `POSTGRES_DB` - Set to "messagequest"
- `POSTGRES_USER` - Set to "postgres"
- `SUPABASE_URL` - Automatically set to your app domain
- `APNS_BUNDLE_ID` - Set to "com.messagequest.app"

## Deployment Steps

1. **Create the app using the CLI:**
   ```bash
   doctl apps create --spec app.yaml
   ```

2. **Or deploy using the DigitalOcean dashboard:**
   - Go to DigitalOcean App Platform
   - Click "Create App"
   - Connect your GitHub repository
   - Select the `mq-server` directory as the source
   - Use the `Dockerfile.digitalocean` as the Dockerfile path
   - Configure environment variables

3. **Update environment variables:**
   ```bash
   doctl apps update YOUR_APP_ID --spec app.yaml
   ```

4. **Monitor deployment:**
   ```bash
   doctl apps logs YOUR_APP_ID --follow
   ```

## Health Checks

The server exposes these endpoints for monitoring:
- `/health` - Basic health check
- `/` - API information
- `/info` - Detailed service status

## Database Migration

After deployment, you'll need to run the Supabase migrations:

1. Connect to your Supabase project
2. Run the migrations in the SQL editor:
   - `001_initial_schema.sql`
   - `002_row_level_security.sql`
   - `003_realtime_and_functions.sql`

## Troubleshooting

### Port Issues
- DigitalOcean expects apps to run on port 8080
- The server automatically uses `process.env.PORT` if available

### Build Failures
- Check that all npm dependencies are listed in package.json
- Ensure the Dockerfile path is correct in app settings

### Connection Issues
- Verify all environment variables are set correctly
- Check that the Supabase project is accessible
- Ensure CORS is properly configured