import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE'
  table: string
  record: {
    id: string
    chat_id: string
    sender_id: string
    content: string
    type: string
  }
  old_record?: any
}

serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json()
    
    // Only process INSERT events on messages table
    if (payload.type !== 'INSERT' || payload.table !== 'messages') {
      return new Response('Not a message insert', { status: 200 })
    }
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    const message = payload.record
    
    // Get sender info
    const { data: sender } = await supabase
      .from('profiles')
      .select('display_name')
      .eq('id', message.sender_id)
      .single()
    
    // Get chat info
    const { data: chat } = await supabase
      .from('chats')
      .select('name, type')
      .eq('id', message.chat_id)
      .single()
    
    // Get all recipients (participants except sender)
    const { data: recipients } = await supabase
      .from('chat_participant_tokens')
      .select('user_id, token')
      .eq('chat_id', message.chat_id)
      .neq('user_id', message.sender_id)
    
    if (!recipients || recipients.length === 0) {
      return new Response('No recipients with push tokens', { status: 200 })
    }
    
    // Prepare notification
    const title = chat?.type === 'direct' ? sender?.display_name : chat?.name
    const body = message.content
    
    // Send notifications to all recipients
    const pushPromises = recipients.map(async (recipient) => {
      const response = await fetch(`${supabaseUrl}/functions/v1/send-push-notification`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${supabaseServiceKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          deviceToken: recipient.token,
          title: title || 'New Message',
          body: body,
          badge: 1,
          data: {
            chatId: message.chat_id,
            messageId: message.id,
            senderId: message.sender_id,
          }
        })
      })
      
      const result = await response.json()
      return { recipient: recipient.user_id, result }
    })
    
    const results = await Promise.allSettled(pushPromises)
    
    return new Response(JSON.stringify({ 
      success: true, 
      notificationsSent: results.length,
      results: results.map(r => r.status === 'fulfilled' ? r.value : { error: r.reason })
    }), {
      headers: { 'Content-Type': 'application/json' },
    })
    
  } catch (error) {
    console.error('Webhook error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})