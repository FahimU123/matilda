import Link from "next/link";
import { MatildaMark } from "@/components/MatildaMark";

const exchange = [
  { who: "Pharmacist", text: "Can I get his date of birth?" },
  { who: "Matilda", text: "His date of birth is March 4, 1952." },
  { who: "Pharmacist", text: "Pickup or delivery?" },
  { who: "Ray", text: "Nods at Pickup." },
  { who: "Matilda", text: "Pickup, please." },
];

export default function Home() {
  return (
    <main className="mx-auto max-w-5xl px-5 pb-20 pt-10">
      <nav className="flex items-center justify-between">
        <span className="text-2xl font-semibold">Matilda</span>
        <div className="flex gap-6 text-lg">
          <Link href="/family" className="underline-offset-4 hover:underline">
            Family setup
          </Link>
          <Link href="/line" className="underline-offset-4 hover:underline">
            Demo phone line
          </Link>
        </div>
      </nav>

      <section className="mt-16 grid gap-12 md:grid-cols-[1.1fr_1fr] md:items-center">
        <div>
          <h1 className="text-5xl font-semibold leading-[1.05] tracking-tight md:text-6xl">
            Giving a voice to the voiceless
          </h1>
          <p className="mt-6 max-w-[34ch] text-xl text-ink-soft">
            Matilda speaks for you on phone calls. You stay on the line, and you say each answer with a nod, a thumbs
            up, or your lips.
          </p>
        </div>

        <ol className="space-y-3" aria-label="A call with Matilda">
          {exchange.map((line, index) =>
            line.who === "Ray" ? (
              <li key={index} className="flex items-center gap-3 py-1 pl-1 text-lg text-confirm">
                <MatildaMark className="h-4 w-7" />
                Ray nods. No typing, no talking.
              </li>
            ) : (
              <li
                key={index}
                className={`max-w-[90%] rounded-2xl px-5 py-4 text-lg ${
                  line.who === "Matilda" ? "bg-ink text-white" : "ml-auto bg-paper"
                }`}
              >
                <span className={`block text-sm ${line.who === "Matilda" ? "text-white/60" : "text-ink-soft"}`}>
                  {line.who === "Matilda" ? "Matilda, speaking for Ray" : line.who}
                </span>
                {line.text}
              </li>
            ),
          )}
        </ol>
      </section>

      <section className="mt-20 grid gap-8 border-t border-rule pt-12 md:grid-cols-3">
        <Point title="It knows the answer">
          Birthdays, prescription numbers and addresses are set up once by family. When the question comes, the answer
          is already on screen.
        </Point>
        <Point title="You decide every word">
          Nothing is said until you say it. Shake your head and Matilda tells them it's not right.
        </Point>
        <Point title="Built for real bodies">
          Large text, no typing, and inputs that work with a tremor or a soft voice.
        </Point>
      </section>
    </main>
  );
}

function Point({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <h2 className="text-xl font-semibold">{title}</h2>
      <p className="mt-2 text-ink-soft">{children}</p>
    </div>
  );
}
