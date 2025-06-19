import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

serve(async (req) => {
  try {
    const payload = await req.json()
    
    // Log environment variables (without exposing sensitive data)
    const envCheck = {
      APNS_KEY_ID: !!Deno.env.get('APNS_KEY_ID'),
      APNS_TEAM_ID: !!Deno.env.get('APNS_TEAM_ID'),
      APNS_BUNDLE_ID: !!Deno.env.get('APNS_BUNDLE_ID'),
      APNS_PRIVATE_KEY: !!Deno.env.get('APNS_PRIVATE_KEY'),
      APNS_PRIVATE_KEY_LENGTH: Deno.env.get('APNS_PRIVATE_KEY')?.length || 0,
      APNS_PRODUCTION: Deno.env.get('APNS_PRODUCTION'),
    }
    
    // Check if private key looks valid
    const privateKey = Deno.env.get('APNS_PRIVATE_KEY') || ''
    const keyValidation = {
      hasBeginMarker: privateKey.includes('BEGIN PRIVATE KEY'),
      hasEndMarker: privateKey.includes('END PRIVATE KEY'),
      approximateLength: privateKey.length,
    }
    
    return new Response(JSON.stringify({
      message: 'Diagnostic test',
      payload,
      envCheck,
      keyValidation,
      timestamp: new Date().toISOString(),
    }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ 
      error: error.message,
      stack: error.stack,
    }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})