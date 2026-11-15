# Matilda

Giving a voice to the voiceless.

Matilda is a phone voice for people whose own voice is hard to understand or gone, starting with Parkinson's. Matilda places the call and speaks clearly. The person stays on the line, sees each question in large text with the answer already filled in from their details, and says it with a thumbs up, a nod through AirPods, a mouthed word, or a tap. Matilda never speaks for them without that approval.

## How a question flows

```
Pharmacist asks "Date of birth?"
  -> ElevenLabs agent (Gemini) calls the ask_user webhook and says "One moment, Ray is answering."
  -> server: Gemini maps the question to a profile detail, builds an answer card, holds the webhook open
  -> iPhone: card appears, Ray gives a thumbs up (Vision) or nods (AirPods head motion)
  -> server resolves the webhook with "His date of birth is March 4, 1952."
  -> Matilda says exactly that sentence
```

Private numbers (social security, card numbers) never reach the server. The server only knows the last four digits; the iPhone reads the full number from the Keychain after Face ID and the consent log stores it masked.

## Repository

| Path | What it is |
| --- | --- |
| `server/` | Fastify + TypeScript. Call state machine, answer cards, pending ask registry, ElevenLabs webhook, Gemini analyzer, MongoDB or in-memory store |
| `web/` | Next.js. Landing page, `/line` (the phone a judge answers, ElevenLabs WebRTC), `/family` (caregiver setup with SSOJet sign-in) |
| `ios/` | SwiftUI app. Places, live call screen, hands-free input, Keychain vault, SwiftData call history |
| `lipread/` | Python service running Auto-AVSR, an open-source lip-reading model, on your own computer |

Hands-free input on iOS runs entirely on the device. One ARKit face-tracking session does three jobs: TrueDepth blendshapes notice when a word is mouthed, the same frames go to Vision hand pose for thumbs up and down, and a two-second clip around each mouthed word goes to the lip reader. Nods and head shakes come from `CMHeadphoneMotionManager`. The decision logic for each signal is a small pure type with unit tests.

Design choices come from Apple's accessibility guidance and research on people with Parkinson's: answer targets of 96 points (the 14 mm that tremor studies recommend), no timed controls, every gesture backed by an on-screen button, every state shown with an icon and a word, a distinct haptic for confirm, not right and call end, a practice question on first launch, and an Assistive Access scene so Matilda works in Apple's simplified mode.

## Run it

Requirements: Node 22+, Xcode 27, an iPhone with Face ID for camera input, AirPods Pro or AirPods (3rd generation or later) for nods. Everything uses free tiers.

```sh
# server
cd server && cp .env.example .env && npm install && npm run dev

# web
cd web && cp .env.example .env.local && npm install && npm run dev

# lip reader (Python 3.12, uv)
cd lipread && ./scripts/fetch_models.sh && uv run uvicorn matilda_lipread.app:app --port 8790

# iOS
cd ios && cp Config/Matilda.xcconfig.example Config/Matilda.xcconfig
xcodegen generate && open Matilda.xcodeproj
```

Without keys the server runs on an in-memory store and a keyword analyzer, which is enough to run the iPhone app and the web pages locally. Add keys to turn on each service:

| Key | Where | Free source |
| --- | --- | --- |
| `ELEVENLABS_API_KEY` | `server/.env` | Hack The Nest Creator plan code |
| `ELEVENLABS_AGENT_ID` | `server/.env` | printed by `npm run agent:sync` once `PUBLIC_URL` is reachable |
| `GEMINI_API_KEY` | `server/.env` | aistudio.google.com |
| `MONGODB_URI` | `server/.env` | MongoDB Atlas free tier |
| `SSOJET_ISSUER`, `SSOJET_CLIENT_ID`, `SSOJET_CLIENT_SECRET` | `web/.env.local`, issuer also in `server/.env` | SSOJet free plan |
| `MATILDA_SERVER_URL`, `MATILDA_DEVELOPMENT_TEAM` | `ios/Config/Matilda.xcconfig` | your server address, your free Apple ID team |
| `APP_KEY` / `NEXT_PUBLIC_APP_KEY` / `MATILDA_APP_KEY` | `server/.env`, `web/.env.local`, `ios/Config/Matilda.xcconfig` | one shared secret so only your phone and line page can join a call; same value in all three |

The `/line` page needs HTTPS on a phone because browsers only allow the microphone on secure origins. Deploy `web` and `server` (for example Vultr with Caddy) or tunnel them.

## Tests

```sh
cd server && npm test        # call coordinator, answer cards, pending asks, analyzer
cd lipread && uv run pytest  # CTC decoding, mouth crops, command mapping
cd ios && xcodebuild test -scheme Matilda -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Lip reading

`lipread/` runs [Auto-AVSR](https://github.com/mpc001/auto_avsr) (visual-only, LRS3) as an int8 ONNX model on the CPU. Each clip goes through the same preparation the model was trained with: MediaPipe BlazeFace keypoints, gap filling, smoothing, a similarity transform onto the reference face, and an 88 by 88 grayscale mouth crop. Greedy CTC decoding gives text, which maps to yes, no, one, two or three, including words that look the same on the lips. A two-second clip takes about 0.2 seconds on an Apple silicon laptop. The model weights are licensed for research and non-commercial use only.

## Built with

ElevenLabs Agents, Gemini, MongoDB Atlas, SSOJet, Vultr, Auto-AVSR, MediaPipe, ONNX Runtime, SwiftUI, SwiftData, ARKit, Vision, Core Motion, Next.js, Fastify.

Synthetic data only. Matilda is a communication aid and gives no medical advice.

## License

MIT
