import type { Metadata, Viewport } from "next";
import { Atkinson_Hyperlegible_Next } from "next/font/google";
import "./globals.css";

const atkinson = Atkinson_Hyperlegible_Next({
  variable: "--font-atkinson",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Matilda",
  description: "Giving a voice to the voiceless. Matilda speaks for you on phone calls while you stay in the conversation.",
};

export const viewport: Viewport = {
  themeColor: "#eef3f1",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={atkinson.variable}>
      <body className="min-h-dvh">{children}</body>
    </html>
  );
}
