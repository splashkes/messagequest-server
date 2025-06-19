import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create, getNumericDate } from 'https://deno.land/x/djwt@v2.9.1/mod.ts'

const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')!
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')!
const APNS_BUNDLE_ID = Deno.env.get('APNS_BUNDLE_ID')!
const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY')!
const APNS_PRODUCTION = Deno.env.get('APNS_PRODUCTION') === 'true'

interface PushPayload {
  userId?: string
  deviceToken?: string
  title: string
  body: string
  data?: Record<string, any>
  badge?: number
  sound?: string
}

// Convert PEM to CryptoKey
async function pemToCryptoKey(pem: string) {
  const pemHeader = "-----BEGIN PRIVATE KEY-----"
  const pemFooter = "-----END PRIVATE KEY-----"
  const pemContents = pem.substring(
    pemHeader.length,
    pem.length - pemFooter.length - 1,
  ).replace(/\s/g, '')
  
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))
  
  return await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    {
      name: "ECDSA",
      namedCurve: "P-256",
    },
    false,
    ["sign"],
  )
}

serve(async (req) => {
  try {
    const { userId, deviceToken, title, body, data, badge, sound } = await req.json() as PushPayload

    let tokens: { token: string }[] = []

    if (deviceToken) {
      tokens = [{ token: deviceToken }]
    } else if (userId) {
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      )

      const { data: dbTokens, error } = await supabase
        .from('push_tokens')
        .select('token')
        .eq('user_id', userId)
        .eq('platform', 'ios')

      if (error || !dbTokens?.length) {
        return new Response(JSON.stringify({ error: 'No push tokens found' }), {
          status: 404,
          headers: { 'Content-Type': 'application/json' },
        })
      }
      tokens = dbTokens
    } else {
      return new Response(JSON.stringify({ error: 'Must provide either userId or deviceToken' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Create JWT for APNS
    const key = await pemToCryptoKey(APNS_PRIVATE_KEY)
    
    const jwt = await create(
      { alg: "ES256", typ: "JWT", kid: APNS_KEY_ID },
      { 
        iss: APNS_TEAM_ID,
        iat: getNumericDate(0),
      },
      key
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
            badge: badge || 0,
            sound: sound || 'default',
          },
          ...data,
        }

        const response = await fetch(endpoint, {
          method: 'POST',
          headers: {
            'authorization': `bearer ${jwt}`,
            'apns-topic': APNS_BUNDLE_ID,
            'apns-push-type': 'alert',
            'apns-priority': '10',
            'apns-expiration': '0',
          },
          body: JSON.stringify(payload),
        })

        if (!response.ok) {
          const errorText = await response.text()
          console.error(`APNS error for token ${deviceToken}: ${response.status} - ${errorText}`)
          throw new Error(`APNS error: ${response.status} - ${errorText}`)
        }

        return { 
          success: true, 
          token: deviceToken,
          status: response.status 
        }
      })
    )

    // Format results
    const formattedResults = results.map((result, index) => {
      if (result.status === 'fulfilled') {
        return result.value
      } else {
        return {
          success: false,
          token: tokens[index].token,
          error: result.reason.message
        }
      }
    })

    return new Response(JSON.stringify({ 
      success: true,
      results: formattedResults 
    }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('Push notification error:', error)
    return new Response(JSON.stringify({ 
      success: false,
      error: error.message,
      stack: error.stack 
    }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})