"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { MatildaMark } from "@/components/MatildaMark";
import { methodLabel, type CallRecord, type Place, type Profile, type ProfileField } from "@/lib/api";

type Session = { configured: boolean; signedIn: boolean; name: string | null };
type SaveState = "idle" | "saving" | "saved" | "error";

export default function FamilyPage() {
  const [session, setSession] = useState<Session>();
  const [profile, setProfile] = useState<Profile>();
  const [calls, setCalls] = useState<CallRecord[]>([]);
  const [saveState, setSaveState] = useState<SaveState>("idle");
  const [loadError, setLoadError] = useState<string>();

  const load = useCallback(async () => {
    const current = (await (await fetch("/api/auth/session")).json()) as Session;
    setSession(current);
    if (current.configured && !current.signedIn) return;

    const [profileResponse, callsResponse] = await Promise.all([fetch("/api/family/profile"), fetch("/api/family/calls")]);
    if (!profileResponse.ok) {
      setLoadError("The Matilda server did not respond. Check that it is running and NEXT_PUBLIC_SERVER_URL is set.");
      return;
    }
    setProfile(await profileResponse.json());
    if (callsResponse.ok) setCalls(await callsResponse.json());
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const [dirty, setDirty] = useState(0);

  useEffect(() => {
    if (!profile || dirty === 0) return;
    setSaveState("saving");
    const timer = setTimeout(async () => {
      const response = await fetch("/api/family/profile", { method: "PUT", body: JSON.stringify(savable(profile)) });
      setSaveState(response.ok ? "saved" : "error");
    }, 700);
    return () => clearTimeout(timer);
  }, [profile, dirty]);

  const update = (change: (draft: Profile) => Profile) => {
    setProfile((current) => (current ? change(current) : current));
    setDirty((count) => count + 1);
  };

  if (session?.configured && !session.signedIn) return <SignIn />;

  return (
    <main className="mx-auto max-w-3xl px-5 pb-24 pt-10">
      <header className="flex flex-wrap items-baseline justify-between gap-4 border-b border-rule pb-6">
        <div>
          <Link href="/" className="text-lg font-semibold text-ink">
            Matilda
          </Link>
          <h1 className="mt-2 text-4xl font-semibold">
            {profile ? `${profile.displayName}'s phone setup` : "Phone setup"}
          </h1>
        </div>
        <p className="text-ink-soft" role="status">
          {saveState === "saving" && "Saving…"}
          {saveState === "saved" && "Saved"}
          {saveState === "error" && "Not saved. Check your connection."}
        </p>
        {session?.signedIn && (
          <form action="/api/auth/logout" method="post" className="text-ink-soft">
            Signed in as {session.name}.{" "}
            <button className="underline underline-offset-4 hover:text-ink">Sign out</button>
          </form>
        )}
      </header>

      {loadError && <p className="mt-8 rounded-lg bg-wait-soft p-4">{loadError}</p>}

      {profile && (
        <>
          <Section
            title={`${profile.displayName}'s details`}
            detail={`When someone asks, ${profile.displayName} sees the answer ready and says it with a nod. Private numbers keep only the last 4 digits here; the full number stays on ${profile.displayName}'s phone behind Face ID.`}
          >
            <FieldList
              fields={profile.fields}
              onChange={(fields) => update((draft) => ({ ...draft, fields }))}
            />
          </Section>

          <Section title="Places" detail={`Each place becomes a big button on ${profile.displayName}'s phone.`}>
            <PlaceList
              places={profile.places}
              fields={profile.fields}
              onChange={(places) => update((draft) => ({ ...draft, places }))}
            />
          </Section>

          <Section title="Recent calls" detail="Every answer is logged with how it was said.">
            <CallHistory calls={calls} places={profile.places} />
          </Section>
        </>
      )}
    </main>
  );
}

function SignIn() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center px-5">
      <p className="text-lg font-semibold text-ink">Matilda</p>
      <h1 className="mt-2 text-4xl font-semibold">Family sign in</h1>
      <p className="mt-3 text-ink-soft">
        This page holds personal details Matilda uses on calls, so only approved family members can open it.
      </p>
      <a
        href="/api/auth/login"
        className="mt-8 rounded-lg bg-ink px-6 py-4 text-center text-lg font-semibold text-white hover:bg-ink/90"
      >
        Sign in
      </a>
    </main>
  );
}

function Section({ title, detail, children }: { title: string; detail: string; children: React.ReactNode }) {
  return (
    <section className="mt-12">
      <h2 className="text-2xl font-semibold">{title}</h2>
      <p className="mt-1 text-ink-soft">{detail}</p>
      <div className="mt-5">{children}</div>
    </section>
  );
}

const inputClass =
  "w-full rounded-lg border border-rule bg-paper px-3 py-2.5 text-lg outline-none focus:border-confirm";

function FieldList({ fields, onChange }: { fields: ProfileField[]; onChange: (fields: ProfileField[]) => void }) {
  const edit = (index: number, change: Partial<ProfileField>) =>
    onChange(fields.map((field, i) => (i === index ? { ...field, ...change } : field)));

  const add = () => {
    const key = `custom${Date.now().toString(36)}`;
    onChange([...fields, { key, label: "", value: "", sensitive: false }]);
  };

  return (
    <div className="divide-y divide-rule rounded-xl border border-rule bg-paper">
      {fields.map((field, index) => (
        <div key={field.key} className="grid gap-3 p-4 sm:grid-cols-[1fr_1.4fr]">
          <label className="block">
            <span className="sr-only">Label</span>
            <input
              value={field.label}
              placeholder="What they ask for"
              onChange={(event) => edit(index, { label: event.target.value })}
              className="w-full rounded-lg border border-transparent bg-transparent px-3 py-2.5 text-lg font-semibold outline-none hover:border-rule focus:border-confirm"
            />
          </label>
          <div>
            <label className="block">
              <span className="sr-only">{field.label} value</span>
              <input
                value={field.value}
                placeholder={field.sensitive ? "Last 4 digits" : "Answer"}
                maxLength={field.sensitive ? 4 : undefined}
                onChange={(event) => edit(index, { value: event.target.value })}
                className={inputClass}
              />
            </label>
            <label className="mt-2 inline-flex items-center gap-2 text-base text-ink-soft">
              <input
                type="checkbox"
                checked={field.sensitive}
                onChange={(event) => edit(index, { sensitive: event.target.checked, value: "" })}
                className="size-5 accent-confirm"
              />
              Private number
            </label>
          </div>
        </div>
      ))}
      <div className="p-4">
        <button onClick={add} className="font-semibold text-confirm underline-offset-4 hover:underline">
          Add a detail
        </button>
      </div>
    </div>
  );
}

const kindLabel: Record<Place["kind"], string> = {
  pharmacy: "Pharmacy",
  doctor: "Doctor's office",
  insurance: "Insurance",
  caseManager: "Case manager",
  bank: "Bank",
  utility: "Utility",
  other: "Other",
};

function PlaceList({
  places,
  fields,
  onChange,
}: {
  places: Place[];
  fields: ProfileField[];
  onChange: (places: Place[]) => void;
}) {
  const edit = (index: number, change: Partial<Place>) =>
    onChange(places.map((place, i) => (i === index ? { ...place, ...change } : place)));

  const add = () =>
    onChange([
      ...places,
      { id: `place${Date.now().toString(36)}`, name: "", kind: "other", phone: "", purpose: "", fieldKeys: [] },
    ]);

  return (
    <div className="space-y-4">
      {places.map((place, index) => (
        <fieldset key={place.id} className="rounded-xl border border-rule bg-paper p-4">
          <legend className="sr-only">{place.name || "New place"}</legend>
          <div className="grid gap-3 sm:grid-cols-[1.4fr_1fr_1fr]">
            <input
              value={place.name}
              placeholder="Name"
              onChange={(event) => edit(index, { name: event.target.value })}
              className={`${inputClass} font-semibold`}
            />
            <select
              value={place.kind}
              onChange={(event) => edit(index, { kind: event.target.value as Place["kind"] })}
              className={inputClass}
            >
              {Object.entries(kindLabel).map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
            <input
              value={place.phone}
              placeholder="Phone number"
              inputMode="tel"
              onChange={(event) => edit(index, { phone: event.target.value })}
              className={inputClass}
            />
          </div>
          <textarea
            value={place.purpose}
            placeholder="What Matilda should ask for on this call"
            rows={2}
            onChange={(event) => edit(index, { purpose: event.target.value })}
            className={`${inputClass} mt-3 resize-none`}
          />
          <p className="mt-3 text-base text-ink-soft">Have these ready:</p>
          <div className="mt-2 flex flex-wrap gap-2">
            {fields
              .filter((field) => field.label)
              .map((field) => {
                const on = place.fieldKeys.includes(field.key);
                return (
                  <button
                    key={field.key}
                    aria-pressed={on}
                    onClick={() =>
                      edit(index, {
                        fieldKeys: on
                          ? place.fieldKeys.filter((key) => key !== field.key)
                          : [...place.fieldKeys, field.key],
                      })
                    }
                    className={`rounded-full border px-3 py-1.5 text-base ${
                      on ? "border-confirm bg-confirm-soft text-confirm" : "border-rule text-ink-soft"
                    }`}
                  >
                    {field.label}
                  </button>
                );
              })}
          </div>
        </fieldset>
      ))}
      {places.length === 0 && (
        <p className="rounded-xl border border-dashed border-rule p-6 text-ink-soft">
          No places yet. Add the pharmacy or doctor they call most and it becomes a button on their phone.
        </p>
      )}
      <button onClick={add} className="font-semibold text-confirm underline-offset-4 hover:underline">
        Add a place
      </button>
    </div>
  );
}

function CallHistory({ calls, places }: { calls: CallRecord[]; places: Place[] }) {
  if (calls.length === 0) {
    return <p className="text-ink-soft">No calls yet. Calls appear here as soon as they end.</p>;
  }
  return (
    <ol className="space-y-6">
      {calls.map((call) => (
        <li key={call.id} className="border-l-4 border-confirm pl-4">
          <p className="text-base text-ink-soft">
            {places.find((place) => place.id === call.placeId)?.name ?? "Call"},{" "}
            {new Date(call.startedAt).toLocaleString([], { dateStyle: "medium", timeStyle: "short" })}
          </p>
          <p className="mt-1 text-xl font-semibold">{call.summary}</p>
          {call.consents.length > 0 && (
            <table className="mt-3 w-full text-left text-base">
              <thead className="text-ink-soft">
                <tr>
                  <th className="pb-1 font-normal">They asked</th>
                  <th className="pb-1 font-normal">Answer</th>
                  <th className="pb-1 font-normal">Said with</th>
                </tr>
              </thead>
              <tbody>
                {call.consents.map((entry) => (
                  <tr key={entry.at} className="border-t border-rule">
                    <td className="py-2 pr-3">{entry.question}</td>
                    <td className="py-2 pr-3">{entry.answer}</td>
                    <td className="py-2">
                      <span className="inline-flex items-center gap-2 text-confirm">
                        <MatildaMark />
                        {methodLabel[entry.method]}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </li>
      ))}
    </ol>
  );
}

function savable(profile: Profile): Profile {
  const fields = profile.fields.filter((field) => field.label.trim());
  const keys = new Set(fields.map((field) => field.key));
  const places = profile.places
    .filter((place) => place.name.trim())
    .map((place) => ({ ...place, fieldKeys: place.fieldKeys.filter((key) => keys.has(key)) }));
  return { ...profile, fields, places };
}
