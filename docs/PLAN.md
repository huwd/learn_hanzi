# Plan

This document orders the open issues into delivery phases. Phases 0–2 are
committed work; phases 3 and beyond are a directional roadmap to revisit as
earlier phases land.

See `PRODUCT.md` for the vision and user needs this plan is working toward.

---

## Phase 0 — Close out in-flight work

These PRs are already open and should merge before starting new work.

| Issue / PR | Description |
|---|---|
| PR #266 | Fix flaky history spec (CI false failure on asset fingerprints) |
| PR #265 | Advisor advises, settings drive sessions — separates LearningAdvisor from session sizing |

---

## Phase 1 — Foundation

Make the app solid and observable before layering on features. Both items here
are bounded and high-value.

| Issue | Description | Why now |
|---|---|---|
| #128 | Error tracking — GlitchTip SDK + lograge structured logging | Know when things break in production without SSHing in |
| #219 | Stable fixed-height flashcard UI with adaptive font scaling | Layout shift on reveal is the biggest UX friction in the core learning loop |

---

## Phase 2 — Data quality

Enrich the dictionary that everything downstream depends on. Issue #226 builds
directly on #206, so the ordering within this phase matters.

| Issue | Description | Why now |
|---|---|---|
| #205 | 49 HSK 3.0 words absent from CC-CEDICT and the krmanik TSV | Gaps in the dictionary create gaps in any HSK 3.0 study plan |
| #206 | Import SUBTLEX-CH word frequency data | Frequency data unlocks better meaning priority and graded reading |
| #226 | Multi-source dictionary hierarchy with learner-optimised meaning priority | Depends on #206 for frequency-ordered meanings; makes the dictionary significantly more useful |

---

## Phase 3 — Card enrichment

Richer cards that surface more of what the learner needs without leaving the
flashcard context. Each issue here is standalone.

| Issue | Description |
|---|---|
| #146 | Radical breakdown in /learn contextual panel |
| #225 | Stroke order diagrams for character entries |
| #224 | Pronunciation audio playback for vocabulary entries |

**Note on audio:** #224 targets a simpler solution (pre-existing audio files or
a lightweight TTS) before the Azure Cognitive Services infrastructure in #236 is
in place. Keep them separate.

---

## Phase 4 — Learning mode improvements

Expand what the app can do with the data it now tracks.

| Issue | Description | Notes |
|---|---|---|
| #227 | Remedial learning mode for struggling characters | Confusion drills, side-by-side comparison, mnemonic hooks |
| #209 | Async data export with download history | Moves export off the request cycle; reuses existing DataExportService |
| #222 | Multi-axis skill architecture | Large foundational change — disaggregate meaning / sound / recognition / production; blocks #237 |

---

## Phase 5 — AI features

Requires the LLM and audio platform infrastructure issues (#235, #236) to land
first. Issues within this phase are ordered by dependency.

| Issue | Description | Depends on |
|---|---|---|
| #235 | LLM provider infrastructure and prompt management | — |
| #234 | Onboarding flow for new users | — |
| #220 | MCP server exposing learning state for AI-driven practice | #222 (multi-axis state worth exposing) |
| #223 | Graded reading with inline click-to-reveal | #206 (frequency data for difficulty calibration) |
| #229 | HSK grammar point assessment with contextual exercises | #235 |
| #236 | Audio platform infrastructure (Azure Cognitive Services) | — |
| #228 | Voice input and pronunciation assessment on flashcards | #236 |
| #230 | Voice-to-voice dialogue conversations | #235, #236 |
| #231 | Branching interactive narrative mode | #235 |
| #238 | Content quality review pipeline for AI-generated content | #235 |

---

## Phase 6 — Multi-user and scale

Long-term work that extends the single-learner app toward shared use.

| Issue | Description | Notes |
|---|---|---|
| #233 | Learner progress dashboard with multi-axis skill visualisation | Depends on #222 |
| #232 | Teacher mode with student progress visibility and exercise commissioning | Multi-user complexity |
| #237 | SRS scheduling evolution for multi-axis skill architecture | Depends on #222 |

---

## Deferred / Ongoing

| Issue | Description | Status |
|---|---|---|
| #88 | Import from user-configured Anki decks (not just the hard-coded deck) | Low priority; labelled risk: medium, effort: large |
| #207 / #240 | Mutation testing to verify test suite effectiveness | Can slot in after Phase 1 stabilises; not a CI gate |

Dependabot keeps gem and action versions up to date automatically.

---

## What this plan is not

- A sprint plan — phases are ordered by dependency and value, not by time-box
- A commitment to all issues — later phases will be revised as the product evolves
- A replacement for the issue tracker — individual issues hold the acceptance criteria
