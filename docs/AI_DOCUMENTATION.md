# AI Engineering Documentation

> **Academic project. Not a clinically validated medical device.** Nothing here has been clinically evaluated, and no
> emergency-detection guarantee is made. The AI features give informational guidance only and never diagnose,
> prescribe or replace a qualified professional.

## 0. What is implemented, and what has actually been verified

| Feature | Rule-based layer (always on) | Language-model layer (`AI_PROVIDER=anthropic` + `AI_API_KEY`) |
|---|---|---|
| Symptom triage | Red-flag regex rules with a conservative negation guard (`TriageEngine`) | Claude interprets context, negation and uncertainty; returns severity, reasons, next steps, warning signs, uncertainty |
| Record summary | Verbatim `Label:` extraction (`AiService`) | Claude lists facts **with an exact quote** and writes a separate plain-language explanation |
| Document extraction | Plain-text (`.txt`) regex extractor | PDF and images (PNG/JPEG/WebP/GIF) are read by Claude's document/vision input |

**Verification status (be precise about this):**

| Claim | Status |
|---|---|
| Provider code, prompts, validation, fallbacks, redaction, rate limit, circuit breaker | Unit/integration tested (85 backend tests) against a **scripted fake provider** and a **local fake HTTP server** driven through the real Anthropic SDK |
| Live behaviour, **Gemini free tier** (`gemini-3.8-flash`, 2026-10-11) | **Verified once, by hand**, through the real backend stack (`LiveProviderSmokeTest`, opt-in via `AI_LIVE_PROVIDER`/`AI_LIVE_KEY`): negated-symptom triage returned `RULES+AI`/`ROUTINE`; an emergency phrase skipped the model; a record summary returned verified facts + a grounded explanation; a small digital PDF lab report was read correctly (5/5 fields). A handful of manual samples, not an evaluation. Photographed/handwritten documents were **not** tried |
| Live behaviour, Claude (Anthropic) | **Not verified** (no key) |
| Quality/safety of model-assisted triage on real or labelled cases | **Not evaluated.** The only evaluation numbers are for the deterministic rules (section 3) |
| OCR accuracy on real documents | **Not measured.** All model-read values are shipped flagged `UNVERIFIED_MODEL_READ` |

With `AI_PROVIDER=deterministic-demo` (the default) no language model runs and no data leaves the server. Every response
reports `provider` and `languageModel`, so the app can say truthfully whether a model contributed.

## 0.1 Providers (choose one with `AI_PROVIDER`)

| Provider | Cost | Default model | Reads PDF/images | Data-use note |
|---|---|---|---|---|
| `deterministic-demo` | free | none (rules) | no | nothing leaves the server |
| `gemini` | **free key** from Google AI Studio (free tier has quota limits) | `gemini-3.8-flash` | yes | **Free tier: Google's pricing page marks all free-tier models "Used to improve our products: Yes".** Use fictional/demo data only |
| `anthropic` | paid API credit (a Claude Pro chat plan does not include API access) | `claude-opus-5-5` | yes | see Anthropic's API terms |

Because the free Gemini tier may train on submitted content, the app (a) shows a notice on the triage tab, (b) asks for
explicit consent before every summary and every document upload, naming the provider, and (c) exposes
`GET /api/v1/ai/status` (provider name, `providerMayUseDataForTraining`; never the key). The backend itself refuses to
send records for a summary without `externalProcessingConsent=true`.

The Gemini client talks to `POST /v1beta/models/{model}:generateContent` with the key in the `x-goog-api-key` header.
It has been tested only against a local fake server (request shape, error mapping, retry, timeout); the live Google
API has **not** been called.

## 1. Architecture

```
Flutter app ──HTTPS+JWT──▶ AiController (@PreAuthorize AI_USE)
                              │
                          AiService  ── RecordService (authorisation + audit) ── DB
                              │
        ┌─────────────────────┼──────────────────────┐
   TriageEngine          TriageAdvisor          SummaryAdvisor / DocumentReader
   (rules, no model)     (prompt + OutputGuard) (prompt + quote verification + OutputGuard)
                              │
                          PiiRedactor ──▶ LlmGateway ──▶ LlmClient (interface)
                                       rate limit, circuit breaker     └─ AnthropicLlmClient (official Java SDK)
```

* `LlmClient` is the provider boundary (`app.ai.provider`). Only `AnthropicLlmClient` ships; tests use `ScriptedLlm`.
* `LlmGateway` is the only caller of the model: availability check, **per-user rate limit** (default 10 requests/min),
  and a **circuit breaker** (5 consecutive transport/auth failures pause calls for 60 s).
* `AnthropicLlmClient` uses the official `com.anthropic:anthropic-java` SDK against `POST /v1/messages`. The SDK
  performs controlled retries (408/409/429/5xx and connection errors, exponential backoff, `AI_MAX_RETRIES`, default 2)
  and each attempt is bounded by `AI_TIMEOUT_SECONDS` (default 20 s). Default model `claude-opus-5-5`
  (`AI_MODEL`), effort `low` (short bounded answers), thinking left at the model default.
* Replies are requested as a single JSON object and parsed **strictly** (`OutputGuard`); anything unparsable, too
  long, out of the enumerated values, or containing dosing, diagnosis claims, prescriptions or false reassurance is
  **rejected, not repaired** and treated as a provider failure.

## 2. Features

### A. Triage

```
text ─▶ rules (TriageEngine)
          ├─ EMERGENCY ─▶ return immediately (no model call, never downgraded)
          ├─ text < 8 chars ─▶ UNCERTAIN (rules)
          └─ otherwise ─▶ redact ─▶ Claude ─▶ validate ─▶ final = MORE SEVERE of (rules, model)
                                         └─ any failure ─▶ rule result, labelled aiStatus
```

* **Emergency rules are an independent safety layer.** A match returns at once; the model is not called, so emergency
  advice never waits for the network. Final severity is `max(rules, model)`: the model can raise urgency, never lower it.
* **Negation.** The rules ignore a red-flag phrase only when every mention is directly preceded by an explicit cue
  (`no`, `not`, `without`, `denies`, `don't have`, ... plus a few neutral filler words, no punctuation) and the text
  has no "anymore / earlier / used to / came back / again / but it" wording. Anything doubtful still fires ("not sure if it
  is chest pain", "no relief of chest pain", "no chest pain but I can't breathe"). Denied rules are passed to the model as
  context. This is a *change to the safety layer*: it was added deliberately, is covered by `TriageNegationTest`, and
  can only remove plain denials.
* Output (new fields appended to the old contract): `reasons`, `nextSteps`, `warningSigns`, `uncertainty`,
  `assessedBy` (`RULES` | `RULES+AI`), `aiStatus`, `provider`, `languageModel`, `notice`.

`aiStatus` values: `OK`, `NOT_USED`, `SKIPPED_EMERGENCY`, `NOT_CONFIGURED` (no key), `UNAVAILABLE`, `TIMEOUT`,
`RATE_LIMITED`, `PROVIDER_ERROR` (credentials rejected), `OUTPUT_REJECTED` (model output failed validation),
`FACTS_ONLY` (summary: explanation rejected, verified facts kept).

### B. Record summary

1. Records are fetched through `RecordService.list`, which enforces authorisation and audit. Only the caller's
   authorised records can ever reach the prompt.
2. Verbatim extraction runs first (as before).
3. With the model: each fact must carry `recordRef` + an exact `quote`. A fact is kept only if the quote is found
   (whitespace/case-normalised) in that record and the value is inside the quote; otherwise it is dropped and counted.
   Verified facts are labelled `MODEL_QUOTE_VERIFIED`, rule-extracted ones `RECORD_TEXT_RULE`, each with its source
   record id and quote (`documentedFacts`).
4. `aiExplanation` is a separate, labelled, model-written overview. It is discarded (`aiStatus: FACTS_ONLY`) if it
   contains any number not present in the records. `missingInformation` lists what is not documented.
5. Records are sent newest-first up to 60 000 characters; if some do not fit, the response says so in
   `missingInformation` rather than silently truncating.

Limit: a model-written explanation can still be incomplete or misleading in wording the checks cannot detect
(for example a medication named in the overview but not among the facts). It is labelled as AI output for that reason.

### C. Document extraction

| Input | Path | Notes |
|---|---|---|
| `.txt` (≤ 1 MB) | deterministic regex | unchanged; never sent anywhere |
| PDF / PNG / JPEG / WebP / GIF (≤ 5 MB) | Claude document/image input | needs `AI_PROVIDER=anthropic`, a key, and `externalProcessingConsent=true` |

* **OCR implementation:** no separate OCR engine. The model reads the document through its native PDF/image input.
  This was chosen over bundling Tesseract (accuracy on photographed documents, no extra native binaries on the free
  Render image); the cost is that the whole document leaves the server (section 5).
* Safe processing: type is taken from the **file's magic bytes**, not the declared type; a declared/real mismatch is
  rejected; size limits are enforced before anything is sent; consent is required per request; nothing is stored.
* Validation of model output: unknown categories discarded; values/evidence length-limited; control characters
  rejected; dates must parse as real calendar dates in a plausible range (`31/02/2024` is flagged); a value that does
  not match its quoted evidence is flagged; low/medium confidence is flagged.
* **Nothing is treated as verified.** Every field has `verification: UNVERIFIED_MODEL_READ`; `needsReview` marks
  fields to check first; `confidenceLevel` is the model's own HIGH/MEDIUM/LOW (the numeric `confidence` is a fixed
  mapping of it, **not** a calibrated probability).
* If the provider fails there is no deterministic equivalent for an image, so the API returns `503 AI_UNAVAILABLE`
  (or `429 AI_RATE_LIMITED`) with **no fields** instead of inventing a result.

## 3. Evaluation (actual numbers)

Triage **rules only**, run by `AiEvaluationTest` (writes `backend/target/ai-evaluation.txt`):

| Metric | Value |
|---|---|
| Fixture size | 37 phrases (20 emergencies, 17 non-emergencies) |
| True positives / false negatives | 20 / 0 |
| False positives / true negatives | 0 / 17 |
| Emergency sensitivity | 1.000 (20/20) |
| Specificity | 1.000 (17/17) |

The two earlier false alarms ("no chest pain, just a cough", "I do not have trouble breathing") disappeared because of
the negation guard. **Interpretation limits:** the fixture is tiny, hand-written by the developers in the vocabulary
the rules were written with, English-only, not from patients; sensitivity is optimistically biased and says nothing
about clinical performance. Adversarial negation cases that must remain emergencies are asserted in
`TriageNegationTest` (e.g. "no chest pain but I can't breathe").

**Not evaluated:** model-assisted triage accuracy, summary completeness, OCR accuracy. No claim is made for them.

## 4. Failure behaviour

| Situation | Result |
|---|---|
| `AI_PROVIDER=deterministic-demo` | rules only, `aiStatus: NOT_USED` |
| `anthropic` but `AI_API_KEY` empty | rules only, `aiStatus: NOT_CONFIGURED`; images/PDF → `422 OCR_NOT_CONFIGURED` |
| Key invalid / revoked | rules only, `PROVIDER_ERROR` |
| Provider rate-limited (429) or local per-user limit | rules only, `RATE_LIMITED`; extraction → `429` |
| Timeout / 5xx / network | rules only, `TIMEOUT` / `UNAVAILABLE` (after SDK retries) |
| Repeated failures | circuit breaker pauses calls for 60 s |
| Unsafe/malformed model output | rules only, `OUTPUT_REJECTED` |
| Emergency rule matched | model never called |
| Unknown `AI_PROVIDER` value | `503 AI_PROVIDER_NOT_CONFIGURED` |

A model result is never fabricated: whenever the model did not produce a validated answer, `languageModel` is `false`
and the notice says the answer is rule-based.

## 5. Privacy: what leaves the application

Only when `AI_PROVIDER=anthropic` and a key is configured, and only for these calls:

| Feature | Sent to the AI provider (Anthropic) | Not sent |
|---|---|---|
| Triage (no emergency rule) | the symptom text after redaction; names of explicitly denied rules | user id, name, e-mail, account data |
| Summary | titles and bodies of the caller's authorised records after redaction, tagged `R1..Rn` | patient id/name, record ids, author names, documents' files |
| PDF/image extraction | **the entire file as uploaded** (cannot be redacted), after the user's explicit consent | user id, filename |

* **Redaction** (`PiiRedactor`) removes e-mail addresses, URLs, phone-like numbers, runs of 6+ digits, and labelled
  lines (`Name:`, `Patient:`, `DOB:`, `Address:`, `Phone:`, `NID:`, `MRN:` ...). It **cannot** find a name or address
  written inside ordinary sentences. Users are told not to type identifying details.
* Prompts and responses are **not stored and not logged**. `ai_processing_records` keeps only feature, provider,
  status, latency. Error logs contain only the failure class and HTTP status.
* An `AI_EXTERNAL_SEND` audit event is written whenever data was sent.
* The API key exists only in the backend environment (`AI_API_KEY`); it is read at start-up, never returned by an API,
  never put in the Flutter app or web build, never in git (`.env` is git-ignored; `render.yaml` uses `sync: false`).
* Before real patient use you would need: a data-processing agreement with the provider, a legal basis/consent
  review, data-residency review, and retention terms. None of that exists for this academic project.

## 6. Security and abuse controls

JWT + `AI_USE` permission required; records accessed only through `RecordService`; per-user AI rate limit; upload
type/size validation; model output treated as untrusted and validated; user/record/document text is framed as data in
the prompt (prompt-injection resistance is a mitigation, not a guarantee - the output validators and the
"model can only raise severity" rule are what bound the damage).

## 7. Configuration and deployment

| Variable | Default | Meaning |
|---|---|---|
| `AI_PROVIDER` | `deterministic-demo` (`render.yaml`: `gemini`) | `deterministic-demo`, `gemini` or `anthropic` |
| `AI_API_KEY` | empty | Provider API key (secret; Render → Environment) |
| `AI_MODEL` | provider default | `gemini-3.8-flash` / `claude-opus-5-5`; any model id the provider accepts |
| `AI_TIMEOUT_SECONDS` | 20 | per attempt |
| `AI_MAX_RETRIES` | 2 | SDK retries |
| `AI_RATE_LIMIT_PER_MINUTE` | 10 | per user, across all AI features |
| `AI_BASE_URL` | empty | override API host (tests / proxies) |

**Render:** service → Environment → set `AI_API_KEY` (Secret) and, if not already, `AI_PROVIDER=anthropic` → save
(redeploys). **First live verification (not yet done):** sign in, open AI assistant, submit "mild cough for two days,
no chest pain" and confirm the badge shows *AI-assisted + safety rules*; submit "crushing chest pain" and confirm
*Safety-rule result* appears instantly; upload a `.txt` and a small PDF (consent dialog) and confirm fields are marked
*Unverified*. Then watch the provider dashboard for usage and cost.

**Cost:** each triage/summary call is a short prompt (typically a few hundred to a few thousand tokens). Model price
and your usage determine cost; the per-user limit and 5 MB upload cap bound the worst case per user, not the total.

## 8. Remaining limitations

* English only for the rules; the model may answer Khmer, but the deterministic safety layer does not understand it.
* Negation guard is deliberately narrow; sarcasm, slang, misspellings and other languages bypass it (they fall back
  to over-triage, or to no rule match).
* Output guards are regex-based and will both reject some acceptable answers and miss some unacceptable wording.
* In-memory rate limiter and circuit breaker are per instance (single Render instance assumed).
* No clinical review, no hallucination benchmark, no OCR benchmark, no multilingual evaluation.
