// supabase/functions/send-notification/index.ts
// 관리자가 프론트엔드에서 에이전트 기기로 FCM 푸시 알림을 발송합니다.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { asset_uid, type, title, body } = await req.json()
    // asset_uid가 null이면 전체 발송

    if (!title) {
      return new Response(
        JSON.stringify({ error: '알림 제목은 필수입니다' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // 1. 대상 기기 FCM 토큰 조회
    let query = supabase.from('device_tokens').select('fcm_token, asset_uid')
    if (asset_uid) {
      query = query.eq('asset_uid', asset_uid)
    }
    const { data: tokens, error: tokenError } = await query

    if (tokenError) {
      return new Response(
        JSON.stringify({ error: tokenError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ error: '대상 기기가 없습니다' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // 2. Firebase Admin SDK로 FCM 발송
    const firebaseKeyStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY')
    if (!firebaseKeyStr) {
      return new Response(
        JSON.stringify({ error: 'Firebase 서비스 계정 키가 설정되지 않았습니다' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const firebaseKey = JSON.parse(firebaseKeyStr)
    const projectId = firebaseKey.project_id

    // JWT 생성 (Google OAuth2 for FCM)
    const now = Math.floor(Date.now() / 1000)
    const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
    const payload = btoa(JSON.stringify({
      iss: firebaseKey.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }))

    // RS256 signing
    const encoder = new TextEncoder()
    const keyData = firebaseKey.private_key
      .replace('-----BEGIN PRIVATE KEY-----', '')
      .replace('-----END PRIVATE KEY-----', '')
      .replace(/\n/g, '')

    const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0))
    const cryptoKey = await crypto.subtle.importKey(
      'pkcs8',
      binaryKey,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign'],
    )

    const signatureInput = encoder.encode(`${header}.${payload}`)
    const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', cryptoKey, signatureInput)
    const jwt = `${header}.${payload}.${btoa(String.fromCharCode(...new Uint8Array(signature)))}`

    // Access token 교환
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
    })
    const { access_token } = await tokenResponse.json()

    // FCM v1 API로 발송
    let sentCount = 0
    for (const token of tokens) {
      const fcmResponse = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${access_token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: token.fcm_token,
              notification: { title, body: body ?? '' },
              data: {
                type: type ?? 'general',
                asset_uid: token.asset_uid ?? '',
              },
            },
          }),
        },
      )

      if (fcmResponse.ok) {
        sentCount++
      }
    }

    // 3. 발송 이력 저장
    await supabase.from('notifications').insert(
      tokens.map((t: { asset_uid: string; fcm_token: string }) => ({
        asset_uid: t.asset_uid,
        type: type ?? 'general',
        title,
        body,
      })),
    )

    return new Response(
      JSON.stringify({ success: true, sent_count: sentCount, total: tokens.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
