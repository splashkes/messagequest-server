#!/bin/bash

# Create data directory if it doesn't exist
mkdir -p /pb/pb_data

# Run migrations on first start
if [ ! -f /pb/pb_data/.initialized ]; then
    echo "First run - initializing database..."
    touch /pb/pb_data/.initialized
fi

# Start PocketBase with live reload for development
if [ "$ENVIRONMENT" = "development" ]; then
    /pb/pocketbase serve --http=0.0.0.0:8090 --dev
else
    /pb/pocketbase serve --http=0.0.0.0:8090
fi