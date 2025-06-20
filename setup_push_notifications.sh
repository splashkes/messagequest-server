#!/bin/bash

echo "Setting up push notifications in Supabase..."
echo ""
echo "Please run this SQL in your Supabase SQL Editor:"
echo "https://supabase.com/dashboard/project/zvkecwnrisdiuekoimzt/editor"
echo ""
echo "Copy and paste the following SQL:"
echo ""
echo "----------------------------------------"
cat run_push_setup.sql
echo "----------------------------------------"
echo ""
echo "After running the SQL, you need to create a webhook:"
echo ""
echo "1. Go to: https://supabase.com/dashboard/project/zvkecwnrisdiuekoimzt/database/hooks"
echo "2. Click 'Create a new hook'"
echo "3. Configure:"
echo "   - Name: message-notifications"
echo "   - Table: messages"
echo "   - Events: Insert"
echo "   - URL: https://zvkecwnrisdiuekoimzt.supabase.co/functions/v1/message-notification-webhook"
echo ""
echo "Press Enter to open the SQL Editor..."
read

open "https://supabase.com/dashboard/project/zvkecwnrisdiuekoimzt/editor"