"use client";

import { Conversation } from "@elevenlabs/client";
import { useCallback, useEffect, useRef, useState } from "react";
import { appKey, serverUrl, socketUrl } from "@/lib/api";

export type Utterance =
  | { speaker: "agent" | "other"; text: string }
  | { speaker: "approval"; text: string };

export type LineState =
  | { phase: "offline" }
  | { phase: "idle" }
  | { phase: "incoming"; callId: string; callerName: string; placeName: string }
  | { phase: "connecting"; callId: string; callerName: string; placeName: string }
  | { phase: "live"; callId: string; callerName: string; placeName: string; since: number; speaking: boolean }
  | { phase: "ended"; callerName: string; reason: string };

type RingMessage = { type: "ring"; callId: string; callerName: string; placeName: string };
type HangupMessage = { type: "hangup"; callId: string };
type ApprovedMessage = { type: "approved"; callId: string; method: string; name: string };

const approvalWords: Record<string, string> = {
  thumbs: "gave a thumbs up",
  nod: "nodded",
  lips: "mouthed it",
  tap: "tapped",
  voice: "said yes",
};

export function useLine() {
  const [state, setState] = useState<LineState>({ phase: "offline" });
  const [utterances, setUtterances] = useState<Utterance[]>([]);
  const socket = useRef<WebSocket | null>(null);
  const conversation = useRef<Conversation | null>(null);
  const ringer = useRef<Ringer | null>(null);
  const callIdRef = useRef<string | null>(null);
  const phaseRef = useRef(state.phase);

  useEffect(() => {
    phaseRef.current = state.phase;
  }, [state.phase]);

  const send = useCallback((payload: object) => {
    if (socket.current?.readyState === WebSocket.OPEN) socket.current.send(JSON.stringify(payload));
  }, []);

  const endConversation = useCallback(async (reason: string) => {
    ringer.current?.stop();
    callIdRef.current = null;
    const active = conversation.current;
    conversation.current = null;
    await active?.endSession().catch(() => undefined);
    setState((current) =>
      "callerName" in current ? { phase: "ended", callerName: current.callerName, reason } : current,
    );
  }, []);

  useEffect(() => {
    let closed = false;
    let retry: ReturnType<typeof setTimeout>;

    const connect = () => {
      const ws = new WebSocket(socketUrl(`/ws/line?key=${encodeURIComponent(appKey)}`));
      socket.current = ws;
      ws.onopen = () => setState((current) => (current.phase === "offline" ? { phase: "idle" } : current));
      ws.onclose = () => {
        if (closed) return;
        setState((current) => (current.phase === "idle" ? { phase: "offline" } : current));
        retry = setTimeout(connect, 1500);
      };
      ws.onmessage = (event) => {
        const message = JSON.parse(event.data) as RingMessage | HangupMessage | ApprovedMessage;
        if (message.type === "ring") {
          if (phaseRef.current === "connecting" || phaseRef.current === "live") {
            send({ type: "ended", callId: message.callId });
            return;
          }
          ringer.current?.stop();
          callIdRef.current = message.callId;
          setUtterances([]);
          setState({ phase: "incoming", ...message });
          ringer.current = new Ringer();
          ringer.current.start();
          return;
        }
        if (message.callId !== callIdRef.current) return;
        if (message.type === "approved") {
          const text = `${message.name} ${approvalWords[message.method] ?? "approved"}`;
          setUtterances((list) => [...list, { speaker: "approval", text }]);
        }
        if (message.type === "hangup") void endConversation("Caller hung up");
      };
    };

    connect();
    return () => {
      closed = true;
      clearTimeout(retry);
      socket.current?.close();
      ringer.current?.stop();
      void conversation.current?.endSession();
    };
  }, [send, endConversation]);

  const answer = useCallback(async () => {
    if (state.phase !== "incoming") return;
    ringer.current?.stop();
    const { callId, callerName, placeName } = state;
    setState({ phase: "connecting", callId, callerName, placeName });

    try {
      const response = await fetch(`${serverUrl}/api/calls/${callId}/session`);
      if (!response.ok) throw new Error((await response.json()).error ?? "Could not start the call");
      const { conversationToken, dynamicVariables } = await response.json();

      const session = await Conversation.startSession({
        conversationToken,
        connectionType: "webrtc",
        dynamicVariables,
        onConnect: () => {
          if (callIdRef.current !== callId) return;
          send({ type: "connected", callId });
          setState({ phase: "live", callId, callerName, placeName, since: Date.now(), speaking: false });
        },
        onMessage: ({ message, role }) => {
          const speaker = role === "agent" ? "agent" : "other";
          setUtterances((list) => [...list, { speaker, text: message }]);
          send({ type: "transcript", callId, speaker, text: message });
        },
        onModeChange: ({ mode }) =>
          setState((current) => (current.phase === "live" ? { ...current, speaking: mode === "speaking" } : current)),
        onDisconnect: () => {
          send({ type: "ended", callId });
          if (callIdRef.current === callId) void endConversation("Call ended");
        },
        onError: (message) => {
          if (callIdRef.current === callId) void endConversation(message);
        },
      });
      if (callIdRef.current !== callId) {
        void session.endSession();
        return;
      }
      conversation.current = session;
    } catch (error) {
      send({ type: "ended", callId });
      if (callIdRef.current !== callId) return;
      callIdRef.current = null;
      setState({ phase: "ended", callerName, reason: error instanceof Error ? error.message : "Call failed" });
    }
  }, [state, send, endConversation]);

  const decline = useCallback(() => {
    if (state.phase !== "incoming") return;
    send({ type: "ended", callId: state.callId });
    void endConversation("Declined");
  }, [state, send, endConversation]);

  const hangUp = useCallback(() => void endConversation("You ended the call"), [endConversation]);

  const reset = useCallback(() => setState({ phase: "idle" }), []);

  return { state, utterances, answer, decline, hangUp, reset };
}

class Ringer {
  private context = new AudioContext();
  private timer: ReturnType<typeof setInterval> | undefined;

  start() {
    const burst = () => {
      for (const offset of [0, 0.45]) {
        const osc = this.context.createOscillator();
        const gain = this.context.createGain();
        osc.frequency.value = 440;
        gain.gain.setValueAtTime(0.0001, this.context.currentTime + offset);
        gain.gain.exponentialRampToValueAtTime(0.25, this.context.currentTime + offset + 0.03);
        gain.gain.exponentialRampToValueAtTime(0.0001, this.context.currentTime + offset + 0.4);
        osc.connect(gain).connect(this.context.destination);
        osc.start(this.context.currentTime + offset);
        osc.stop(this.context.currentTime + offset + 0.42);
      }
    };
    void this.context.resume();
    burst();
    this.timer = setInterval(burst, 3000);
  }

  stop() {
    if (this.context.state === "closed") return;
    clearInterval(this.timer);
    this.timer = undefined;
    void this.context.close().catch(() => undefined);
  }
}
