import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

serve(async (req) => {
  try {
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    
    // Get pending notifications from the queue
    const { data: notifications, error } = await supabase
      .rpc('process_notification_queue')
    
    if (error) {
      throw error
    }
    
    if (!notifications || notifications.length === 0) {
      return new Response(JSON.stringify({ 
        message: 'No pending notifications',
        processed: 0 
      }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }
    
    // Send each notification
    const results = await Promise.allSettled(
      notifications.map(async (notification) => {
        const response = await fetch(`${supabaseUrl}/functions/v1/send-push-notification`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${supabaseServiceKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            deviceToken: notification.device_token,
            title: notification.title,
            body: notification.body,
            badge: 1,
            data: notification.data
          })
        })
        
        if (!response.ok) {
          throw new Error(`Failed to send notification: ${response.status}`)
        }
        
        return {
          notificationId: notification.notification_id,
          success: true
        }
      })
    )
    
    // Count successes and failures
    const succeeded = results.filter(r => r.status === 'fulfilled').length
    const failed = results.filter(r => r.status === 'rejected').length
    
    return new Response(JSON.stringify({ 
      message: 'Notifications processed',
      processed: notifications.length,
      succeeded,
      failed,
      results: results.map((r, i) => ({
        notificationId: notifications[i].notification_id,
        status: r.status,
        error: r.status === 'rejected' ? r.reason.message : undefined
      }))
    }), {
      headers: { 'Content-Type': 'application/json' },
    })
    
  } catch (error) {
    console.error('Queue processing error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})