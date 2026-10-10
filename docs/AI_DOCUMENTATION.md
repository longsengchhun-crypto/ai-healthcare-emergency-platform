# AI Engineering Documentation

## 0. What is actually implemented

| Feature | Implementation | Is it a language model? |
|---|---|---|
| Preliminary triage | Deterministic regex red-flag rules (`TriageEngine`) | **No** |
| Medical-record summary | Rule-based extractive summariser over the caller's authorised records (`AiService`) | **No** |
| Document extraction | Regex field extractor for plain-text documents | **No** |

The provider boundary (`app.ai.provider`, `AI_PROVIDER`) exists so a real LLM or OCR service can be plugged in later.
Only `deterministic-demo` ships; any other value makes the AI endpoints answer 503 `AI_PROVIDER_NOT_CONFIGURED`.
Every response states `provider` and `languageModel:false`, and the UI says the output comes from a deterministic
demonstration provider. No AI key is read or required, and none is ever sent to the mobile app.

## 1. Pipeline (all three features)

```
Problem → Input → Preprocessing → Algorithm → Validated output → User/system action → Evaluation
```

### A. Triage

| Stage | Detail |
|---|---|
| Problem | Help a user recognise when symptoms need urgent care, without delaying emergency action |
| Input | Free text (≤ 2000 chars), validated server-side |
| Preprocessing | trim, lower-case |
| Algorithm | 9 red-flag rule groups (chest pain, breathing, stroke signs, unconsciousness/seizure, severe bleeding, self-harm, anaphylaxis, poisoning/overdose, serious head injury/accident) → `EMERGENCY`; 5 urgent groups → `URGENT`; <8 chars → `UNCERTAIN`; otherwise `ROUTINE` |
| Output | `urgency`, matched rule ids, guidance, `emergencyActionRecommended`, follow-up questions, disclaimer |
| Action | `EMERGENCY` shows a "Go to Emergency" button; never gates or delays the SOS control |
| Safety | `ROUTINE` text explicitly says the tool cannot rule out a serious problem. No diagnosis, no medication advice |

### B. Record summary

Retrieve → authorise (same access rules and audit as reading the records directly) → extract lines such as
`Allergy:`, `Medication:`, `Diagnosis:` and ISO/`d/m/yyyy` dates **verbatim** → return with source record ids.
Nothing is inferred, so nothing can be hallucinated; the cost is low recall for free-form prose. Because no
external model is used, no data leaves the server.

### C. Document extraction

Accepts `text/plain` ≤ 1 MB. Extracts medication/allergy lines, dates and `Name: 12.3 unit` values with the
evidence line and a fixed heuristic confidence (0.8–0.95; **not** a calibrated probability). Images and PDFs return
422 `OCR_NOT_CONFIGURED`.

## 2. Evaluation (actual numbers)

Triage rules, run by `AiEvaluationTest` (writes `backend/target/ai-evaluation.txt`):

| Metric | Value |
|---|---|
| Fixture size | 37 phrases (20 emergencies, 17 non-emergencies) |
| True positives / false negatives | 20 / 0 |
| False positives / true negatives | 2 / 15 |
| Emergency sensitivity | 1.000 (20/20) |
| Specificity | 0.882 (15/17) |
| False alarms | "no chest pain, just a cough", "I do not have trouble breathing" |

**Interpretation limits.** The fixture is small, hand-written by the developers in the same vocabulary the rules
were written with, English-only, and not drawn from real patients — so sensitivity is optimistically biased and says
nothing about clinical performance. The two false alarms show the known weakness: **negation is not handled**
(deliberate over-triage). No clinical validation has been performed.

Summary factual consistency: by construction every listed condition/medication/allergy/date is a verbatim substring of
a source record (asserted for allergy/medication in `aiSummaryUsesOnlyRecordedFactsAndIsLabelled`). Recall on
unstructured notes was not measured.

Extraction accuracy: no labelled document set exists, so **no extraction accuracy figure is claimed**.
Failure rate / latency: metadata is stored in `ai_processing_records`; no production traffic exists to report.

## 3. Privacy

Prompts/outputs are not stored; only feature, provider, status and latency. Summaries run on authorised records only
and are audited via the underlying record-access events. When a real LLM provider is added: redact direct identifiers
before sending, send the minimum text, add timeouts/circuit-breaking, and obtain a data-processing agreement.

## 4. Failure modes

* Misspellings, slang, other languages (Khmer is **not** supported) → rules miss → `ROUTINE` with caution text.
* Negation → over-triage (see above).
* Records without `Label:` structure → sparse summaries.
* Scanned documents → not supported.
