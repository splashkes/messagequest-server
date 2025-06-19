import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import jwt from 'https://esm.sh/jsonwebtoken@9.0.0'

const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')!
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')!
const APNS_BUNDLE_ID = Deno.env.get('APNS_BUNDLE_ID')!
const APNS_KEY = Deno.env.get('APNS_KEY')! // P8 key content
const APNS_PRODUCTION = Deno.env.get('APNS_PRODUCTION') === 'true'

interface PushPayload {
  userId: string
  title: string
  body: string
  data?: Record<string, any>
  badge?: number
  sound?: string
}

serve(async (req) => {
  try {
    const { userId, title, body, data, badge, sound } = await req.json() as PushPayload

    // Get user's push tokens
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { data: tokens, error } = await supabase
      .from('push_tokens')
      .select('token')
      .eq('user_id', userId)
      .eq('platform', 'ios')

    if (error || !tokens?.length) {
      return new Response(JSON.stringify({ error: 'No push tokens found' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Create JWT for APNS
    const now = Math.floor(Date.now() / 1000)
    const token = jwt.sign(
      {
        iss: APNS_TEAM_ID,
        iat: now,
      },
      APNS_KEY,
      {
        algorithm: 'ES256',
        keyid: APNS_KEY_ID,
        expiresIn: '1h',
      }
    )

    // Send to each token
    const results = await Promise.allSettled(
      tokens.map(async ({ token: deviceToken }) => {
        const endpoint = APNS_PRODUCTION
          ? `https://api.push.apple.com/3/device/${deviceToken}`
          : `https://api.sandbox.push.apple.com/3/device/${deviceToken}`

        const payload = {
          aps: {
            alert: {
              title,
              body,
            },
            badge,
            sound: sound || 'default',
            'content-available': 1,
          },
          ...data,
        }

        const response = await fetch(endpoint, {
          method: 'POST',
          headers: {
            'Authorization': `bearer ${token}`,
            'apns-topic': APNS_BUNDLE_ID,
            'apns-push-type': 'alert',
            'apns-priority': '10',
          },
          body: JSON.stringify(payload),
        })

        if (!response.ok) {
          const error = await response.text()
          throw new Error(`APNS error: ${response.status} - ${error}`)
        }

        return { success: true, token: deviceToken }
      })
    )

    return new Response(JSON.stringify({ results }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})