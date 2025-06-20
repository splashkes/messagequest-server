#!/bin/bash

# Supabase Webhook Setup Script
# This creates a database webhook for message notifications

echo "Setting up MessageQuest notification webhook..."
echo ""
echo "Please follow these steps in your Supabase Dashboard:"
echo ""
echo "1. Go to: https://supabase.com/dashboard/project/zvkecwnrisdiuekoimzt/database/hooks"
echo ""
echo "2. Click 'Create a new hook'"
echo ""
echo "3. Fill in the following details:"
echo "   - Name: message-notifications"
echo "   - Table: messages"
echo "   - Events: Check only 'Insert'"
echo "   - Type: HTTP Request"
echo "   - Method: POST"
echo "   - URL: https://zvkecwnrisdiuekoimzt.supabase.co/functions/v1/message-notification-webhook"
echo "   - Headers: Leave default"
echo "   - Params: Leave default"
echo ""
echo "4. Click 'Create webhook'"
echo ""
echo "Once created, every new message will trigger push notifications to all chat participants!"
echo ""
echo "Press Enter to open the dashboard..."
read

open "https://supabase.com/dashboard/project/zvkecwnrisdiuekoimzt/database/hooks"