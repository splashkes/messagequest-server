import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { Configuration, OpenAIApi } from 'https://esm.sh/openai@3.2.1'

const configuration = new Configuration({
  apiKey: Deno.env.get('OPENAI_API_KEY'),
})
const openai = new OpenAIApi(configuration)

interface RequestPayload {
  chatId: string
  characterId: string
  userId: string
}

serve(async (req) => {
  try {
    const { chatId, characterId, userId } = await req.json() as RequestPayload

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Get character info
    const { data: character } = await supabase
      .from('characters')
      .select('*')
      .eq('id', characterId)
      .single()

    // Get recent messages for context
    const { data: messages } = await supabase
      .from('messages')
      .select(`
        *,
        sender:profiles(display_name)
      `)
      .eq('chat_id', chatId)
      .order('created_at', { ascending: false })
      .limit(10)

    // Get character's objectives
    const { data: objectives } = await supabase
      .from('objectives')
      .select('*')
      .eq('character_id', characterId)
      .eq('is_secret', false)

    // Build the prompt
    const conversationContext = messages?.reverse().map(m => 
      `${m.sender.display_name}: ${m.content}`
    ).join('\n')

    const objectivesContext = objectives?.map(o => 
      `- ${o.title}: ${o.description}`
    ).join('\n')

    const prompt = `You are playing the character "${character.name}" in a murder mystery role-play game.

Character Profile:
${character.bio}
Role: ${character.role}
Faction: ${character.faction || 'None'}

Your Current Objectives:
${objectivesContext}

Recent Conversation:
${conversationContext}

Generate 3 short, in-character responses that:
1. Stay true to the character's personality and role
2. Advance one or more of your objectives
3. Maintain the mystery and tension
4. Are conversational and natural (1-2 sentences max)

Responses should be separated by newlines.`

    const completion = await openai.createCompletion({
      model: 'text-davinci-003',
      prompt,
      max_tokens: 150,
      temperature: 0.8,
      n: 1,
    })

    const suggestions = completion.data.choices[0].text
      ?.trim()
      .split('\n')
      .filter(s => s.length > 0)
      .slice(0, 3)

    return new Response(JSON.stringify({ suggestions }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})