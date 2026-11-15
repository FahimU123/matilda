import { config } from "../src/config.js";
import { ElevenLabs } from "../src/services/elevenlabs.js";
import { agentPrompt, firstMessage } from "../src/agentPrompt.js";

if (!config.ELEVENLABS_API_KEY) {
  console.error("Set ELEVENLABS_API_KEY first.");
  process.exit(1);
}
if (config.PUBLIC_URL.includes("localhost")) {
  console.error("PUBLIC_URL must be reachable by ElevenLabs (deploy or tunnel the server first).");
  process.exit(1);
}

const client = new ElevenLabs(config.ELEVENLABS_API_KEY, undefined);

const tool = await client.request<{ id: string }>("/tools", {
  method: "POST",
  body: JSON.stringify({
    tool_config: {
      type: "webhook",
      name: "ask_user",
      description:
        "Ask the person you are speaking for how to answer anything about them or any choice they must make. Pass the other person's question word for word. Returns the exact sentence to say next.",
      response_timeout_secs: 120,
      pre_tool_speech: "force",
      execution_mode: "post_tool_speech",
      interruption_mode: "disable_during_tool",
      api_schema: {
        url: `${config.PUBLIC_URL}/tools/ask-user?key=${config.TOOL_SECRET}`,
        method: "POST",
        request_body_schema: {
          type: "object",
          required: ["call_id", "question"],
          properties: {
            call_id: { type: "string", dynamic_variable: "call_id" },
            question: { type: "string", description: "The other person's question, word for word." },
          },
        },
      },
    },
  }),
});

const agent = await client.request<{ agent_id: string }>("/agents/create", {
  method: "POST",
  body: JSON.stringify({
    name: "Matilda",
    conversation_config: {
      agent: {
        first_message: firstMessage(config.DISCLOSE_AI),
        language: "en",
        prompt: {
          prompt: agentPrompt,
          llm: config.ELEVENLABS_LLM,
          tool_ids: [tool.id],
          built_in_tools: {
            end_call: { type: "system", name: "end_call", description: "", params: { system_tool_type: "end_call" } },
          },
        },
      },
      tts: { voice_id: config.ELEVENLABS_VOICE_ID },
    },
  }),
});

console.log(`ELEVENLABS_AGENT_ID=${agent.agent_id}`);
