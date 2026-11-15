"use client";

import { useEffect, useRef, useState } from "react";
import { MatildaMark } from "@/components/MatildaMark";
import { assistantName } from "@/lib/api";
import { useLine, type Utterance } from "./useLine";

export default function LinePage() {
  const { state, utterances, answer, decline, hangUp, reset } = useLine();

  return (
    <main className="flex min-h-dvh flex-col bg-line text-white">
      {state.phase === "offline" && <Waiting title="Connecting the line" detail="Looking for the Matilda server." />}
      {state.phase === "idle" && <Waiting title="Nest Street Pharmacy" detail="This phone is ready for calls." />}

      {(state.phase === "incoming" || state.phase === "connecting") && (
        <section className="flex flex-1 flex-col items-center justify-between px-6 pb-14 pt-24 text-center">
          <div>
            <p className="text-lg text-white/70">Incoming call via Matilda</p>
            <h1 className="mt-3 text-5xl font-semibold tracking-tight">{state.callerName}</h1>
            <p className="mt-4 max-w-xs text-lg text-white/70">
              {assistantName}, an assistant, speaks for {state.callerName}. {state.callerName} is listening and approves every answer.
            </p>
          </div>
          <Avatar name={state.callerName} ringing={state.phase === "incoming"} />
          {state.phase === "incoming" ? (
            <div className="flex w-full max-w-xs justify-between">
              <RoundButton label="Decline" tone="hangup" onClick={decline} />
              <RoundButton label="Answer" tone="answer" onClick={answer} />
            </div>
          ) : (
            <p className="text-lg text-white/70">Connecting</p>
          )}
        </section>
      )}

      {state.phase === "live" && (
        <section className="flex flex-1 flex-col px-6 pb-10 pt-14">
          <header className="text-center">
            <h1 className="text-3xl font-semibold">{state.callerName}</h1>
            <p className="mt-1 text-lg text-white/70">
              <Elapsed since={state.since} /> {state.speaking ? `${assistantName} is speaking` : "Listening"}
            </p>
          </header>
          <Transcript utterances={utterances} callerName={state.callerName} />
          <div className="flex justify-center pt-6">
            <RoundButton label="End" tone="hangup" onClick={hangUp} />
          </div>
        </section>
      )}

      {state.phase === "ended" && (
        <section className="flex flex-1 flex-col items-center justify-center gap-8 px-6 text-center">
          <div>
            <h1 className="text-3xl font-semibold">{state.callerName}</h1>
            <p className="mt-2 text-lg text-white/70">{state.reason}</p>
          </div>
          <button
            onClick={reset}
            className="rounded-full bg-line-raised px-8 py-4 text-lg font-semibold hover:bg-white/15"
          >
            Back to waiting
          </button>
        </section>
      )}
    </main>
  );
}

function Waiting({ title, detail }: { title: string; detail: string }) {
  return (
    <section className="flex flex-1 flex-col items-center justify-center px-6 text-center">
      <h1 className="text-4xl font-semibold">{title}</h1>
      <p className="mt-3 text-lg text-white/70">{detail}</p>
    </section>
  );
}

function Avatar({ name, ringing }: { name: string; ringing: boolean }) {
  return (
    <div className="relative grid size-40 place-items-center">
      {ringing && <span className="absolute inset-0 rounded-full bg-white/30 [animation:ring_2s_ease-out_infinite]" />}
      <span className="relative grid size-40 place-items-center rounded-full bg-line-raised text-6xl font-semibold">
        {name.charAt(0)}
      </span>
    </div>
  );
}

function RoundButton({ label, tone, onClick }: { label: string; tone: "answer" | "hangup"; onClick: () => void }) {
  return (
    <button onClick={onClick} className="flex flex-col items-center gap-3 text-lg">
      <span
        className={`grid size-20 place-items-center rounded-full ${tone === "answer" ? "bg-confirm" : "bg-hangup"}`}
      >
        <PhoneGlyph rotated={tone === "hangup"} />
      </span>
      {label}
    </button>
  );
}

function PhoneGlyph({ rotated }: { rotated: boolean }) {
  return (
    <svg viewBox="0 0 24 24" className={`size-9 fill-white ${rotated ? "rotate-[135deg]" : ""}`} aria-hidden>
      <path d="M6.6 10.8a15.5 15.5 0 0 0 6.6 6.6l2.2-2.2a1 1 0 0 1 1-.25 11.4 11.4 0 0 0 3.6.58 1 1 0 0 1 1 1V20a1 1 0 0 1-1 1A17 17 0 0 1 3 4a1 1 0 0 1 1-1h3.5a1 1 0 0 1 1 1c0 1.25.2 2.45.58 3.57a1 1 0 0 1-.25 1z" />
    </svg>
  );
}

function Elapsed({ since }: { since: number }) {
  const [now, setNow] = useState(since);
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);
  const seconds = Math.max(0, Math.floor((now - since) / 1000));
  return (
    <span className="tabular-nums">
      {Math.floor(seconds / 60)}:{String(seconds % 60).padStart(2, "0")}
    </span>
  );
}

function Transcript({ utterances, callerName }: { utterances: Utterance[]; callerName: string }) {
  const end = useRef<HTMLDivElement>(null);
  useEffect(() => end.current?.scrollIntoView({ behavior: "smooth" }), [utterances]);

  return (
    <div className="mt-8 flex-1 overflow-y-auto" aria-live="polite">
      <ol className="space-y-4">
        {utterances.map((utterance, index) =>
          utterance.speaker === "approval" ? (
            <li key={index} className="flex items-center gap-2 pl-1 text-base text-[#9fd8bd]">
              <MatildaMark className="h-3 w-5" />
              {utterance.text}
            </li>
          ) : (
          <li key={index} className={utterance.speaker === "other" ? "text-right" : ""}>
            <p className="text-sm text-white/60">{utterance.speaker === "agent" ? `${assistantName} for ${callerName}` : "You"}</p>
            <p
              className={`mt-1 inline-block max-w-[85%] rounded-2xl px-4 py-3 text-left text-lg ${
                utterance.speaker === "agent" ? "bg-line-raised" : "bg-white text-ink"
              }`}
            >
              {utterance.text}
            </p>
          </li>
          ),
        )}
      </ol>
      <div ref={end} />
    </div>
  );
}
