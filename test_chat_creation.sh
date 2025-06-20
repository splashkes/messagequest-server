#!/bin/bash

# Test if the ensure_character_chats function exists and works
curl -X POST \
  "https://zvkecwnrisdiuekoimzt.supabase.co/rest/v1/rpc/ensure_character_chats" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp2a2Vjd25yaXNkaXVla29pbXp0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNzY3NDQsImV4cCI6MjA2NTg1Mjc0NH0.xySMFv6czh99DJhC2vdLMtbknD-LxN7BaEGa0WTpUZI" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp2a2Vjd25yaXNkaXVla29pbXp0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNzY3NDQsImV4cCI6MjA2NTg1Mjc0NH0.xySMFv6czh99DJhC2vdLMtbknD-LxN7BaEGa0WTpUZI" \
  -H "Content-Type: application/json" \
  -H "Content-Profile: public" \
  -d '{"p_user_id": "550e8400-e29b-41d4-a716-446655440000"}' | jq