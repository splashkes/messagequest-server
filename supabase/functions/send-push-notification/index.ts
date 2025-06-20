import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create, getNumericDate } from 'https://deno.land/x/djwt@v2.9.1/mod.ts'

const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')!
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')!
const APNS_BUNDLE_ID = Deno.env.get('APNS_BUNDLE_ID')!
const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY')!
// Force production for TestFlight
const APNS_PRODUCTION = true // Deno.env.get('APNS_PRODUCTION') === 'true'

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
  
  // Trim any whitespace and normalize line endings
  const normalizedPem = pem.trim().replace(/\r\n/g, '\n')
  
  // Extract the base64 content between header and footer
  const headerIndex = normalizedPem.indexOf(pemHeader)
  const footerIndex = normalizedPem.indexOf(pemFooter)
  
  if (headerIndex === -1 || footerIndex === -1) {
    throw new Error('Invalid PEM format')
  }
  
  const pemContents = normalizedPem
    .substring(headerIndex + pemHeader.length, footerIndex)
    .replace(/\s/g, '') // Remove all whitespace
  
  console.log('PEM processing:', {
    originalLength: pem.length,
    normalizedLength: normalizedPem.length,
    base64Length: pemContents.length
  })
  
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
    console.log('APNS Config:', {
      keyId: APNS_KEY_ID,
      teamId: APNS_TEAM_ID,
      bundleId: APNS_BUNDLE_ID,
      production: APNS_PRODUCTION,
      privateKeyLength: APNS_PRIVATE_KEY?.length,
      privateKeyStart: APNS_PRIVATE_KEY?.substring(0, 50)
    })
    
    // Validate the values match expected
    if (APNS_KEY_ID !== 'J48BV28YFZ') {
      console.error('Unexpected APNS_KEY_ID:', APNS_KEY_ID)
    }
    if (APNS_TEAM_ID !== 'BDV8CS4763') {
      console.error('Unexpected APNS_TEAM_ID:', APNS_TEAM_ID)
    }
    if (APNS_BUNDLE_ID !== 'artbattle.MessageQuest') {
      console.error('Unexpected APNS_BUNDLE_ID:', APNS_BUNDLE_ID)
    }
    
    const key = await pemToCryptoKey(APNS_PRIVATE_KEY)
    
    const now = Math.floor(Date.now() / 1000)
    const jwtPayload = { 
      iss: APNS_TEAM_ID,
      iat: now,
      exp: now + 3600, // Token expires in 1 hour
    }
    
    console.log('JWT payload:', jwtPayload)
    
    const jwt = await create(
      { alg: "ES256", typ: "JWT", kid: APNS_KEY_ID },
      jwtPayload,
      key
    )
    
    console.log('JWT created, length:', jwt.length)

    // Send to each token
    const results = await Promise.allSettled(
      tokens.map(async ({ token: deviceToken }) => {
        const endpoint = APNS_PRODUCTION
          ? `https://api.push.apple.com/3/device/${deviceToken}`
          : `https://api.sandbox.push.apple.com/3/device/${deviceToken}`
        
        console.log(`Using APNS endpoint: ${endpoint}`)

        const payload = {
          aps: {
            alert: {
              title: title || 'MessageQuest',
              body: body || 'You have a new message',
            },
            badge: badge !== undefined ? badge : 1,
            sound: sound || 'default',
            'content-available': 1,
          },
          ...data,
        }
        
        console.log('Sending payload:', JSON.stringify(payload))

        // Log the full request details
        console.log('APNS Request:', {
          endpoint: endpoint.substring(0, 50) + '...',
          bundleId: APNS_BUNDLE_ID,
          jwtHeader: jwt.split('.')[0],
          teamId: APNS_TEAM_ID,
          keyId: APNS_KEY_ID
        })
        
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
        
        // Log the response headers for debugging
        if (!response.ok) {
          console.log(`APNS Response Status: ${response.status}`)
          console.log(`APNS Response Headers:`, Object.fromEntries(response.headers.entries()))
        }

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