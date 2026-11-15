const API = "https://api.elevenlabs.io/v1/convai";

export class ElevenLabsUnavailable extends Error {}

export class ElevenLabs {
  constructor(
    private readonly apiKey: string | undefined,
    readonly agentId: string | undefined,
  ) {}

  get configured(): boolean {
    return Boolean(this.apiKey && this.agentId);
  }

  async conversationToken(): Promise<string> {
    if (!this.apiKey || !this.agentId) {
      throw new ElevenLabsUnavailable("Set ELEVENLABS_API_KEY and ELEVENLABS_AGENT_ID (run npm run agent:sync)");
    }
    const body = await this.request<{ token: string }>(`/conversation/token?agent_id=${encodeURIComponent(this.agentId)}`);
    return body.token;
  }

  async request<T>(path: string, init: RequestInit = {}): Promise<T> {
    const response = await fetch(`${API}${path}`, {
      ...init,
      headers: { "xi-api-key": this.apiKey ?? "", "content-type": "application/json", ...init.headers },
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) {
      throw new ElevenLabsUnavailable(`ElevenLabs ${response.status}: ${await response.text()}`);
    }
    return (await response.json()) as T;
  }
}
