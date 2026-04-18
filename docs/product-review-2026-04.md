# Product Review — April 2026

A review of the issues raised in the April 2026 planning session, assessing
coherence, gaps, and sequencing across the full roadmap.

---

## What was planned

Fourteen new issues were created covering: flashcard UI stability, an MCP
server for AI-driven practice, multi-axis skill tracking, graded reading,
pronunciation audio, stroke order diagrams, dictionary hierarchy, remedial
learning, voice input, grammar assessment, voice-to-voice dialogue, interactive
narrative, and a teacher mode.

---

## What it adds up to

Five distinct layers, each building on the last:

### Layer 1 — Data enrichment
*What is this word?*

Making each vocabulary entry richer. Not just character + meaning + pinyin, but
frequency rank, audio pronunciation, stroke order, radical breakdown, example
sentences, and better-sourced definitions.

Issues: #206, #224, #225, #226, #146, #142

### Layer 2 — Precision skill tracking
*How well do I know it?*

The central nervous system. Replaces a single SRS ease score with independently
trackable per-axis mastery signals. Everything from Layer 3 onwards depends on
this schema existing.

Issue: #222

### Layer 3 — Practice modes
*Can I use it?*

Progressively more naturalistic practice. Flashcard → reading in context →
targeted remediation → pronunciation production → grammar drills.

Issues: #219, #223, #227, #228, #229

### Layer 4 — AI-powered contextual practice
*Can I deploy it under pressure?*

The MCP server bridges the skill profile to AI agents that run calibrated
dialogue, narrative, and scenario exercises. The profile informs what the agent
emphasises; the agent's retrospective writes back new skill signals.

Issues: #220, #230, #231

### Layer 5 — Social and institutional
*Can others see and support my progress?*

Teacher mode as the accountability and visibility layer. Student controls what
is shared; teacher gains a data-backed view of progress, consistency, and gaps.

Issue: #232

---

## Coherence assessment

**Yes, broadly coherent.** The learning theory underpinning it — know what you
know precisely, practice in context, get feedback — is sound pedagogy. The
progression from isolated flashcard to immersive voice dialogue to human-teacher
oversight maps naturally onto how language proficiency actually develops.

The through-line: *the learning log is the product*. Every exercise type is
ultimately a way to generate higher-quality signals into that log.

The existing product vision in `docs/PRODUCT.md` anticipated most of this
(axis-based learning, progressive richness, contextual generation) — the April
2026 session translated those ideas into concrete GitHub issues and connected
them to each other.

**Note on ADR 0002:** the decision to defer multi-modality (recorded in
`docs/adr/0002-review-modalities.md`) is now superseded by #222. A new ADR
should be written to record the multi-axis decision, the SRS scheduling
implications, and how Anki-sourced data seeds the initial axis records.

---

## What is missing

### 1. Learner progress dashboard → #233

The most significant gap. #232 (teacher mode) describes a rich student view,
but there is no issue for the student's own dashboard showing multi-axis mastery,
trajectory over time, knowledge gaps toward HSK target, and struggling areas.
The data from #222 has nowhere to surface for the learner themselves.

### 2. Onboarding → #234

No issue covers how a new user starts: setting target HSK level, connecting
Anki, understanding what the system is doing. With this many features, onboarding
will determine whether the system is usable at all for anyone beyond the
original author.

### 3. LLM / AI infrastructure → #235

Six issues (#227, #229, #230, #231, and indirectly #220 and #232) depend on
calling a language model. No issue covers: which model, how prompts are managed,
cost controls, rate limiting, or API failure handling. This is a hidden
dependency touching the majority of the advanced feature set.

### 4. Audio platform infrastructure → #236

Azure Cognitive Services is recommended across #228 (pronunciation assessment),
#230 (TTS for dialogue), and #231 (TTS narration). No issue covers account
setup, key management, rate limiting, or the billing model. Should be one
infrastructure issue that precedes the first audio feature.

### 5. SRS scheduling evolution → #237

#222 disaggregates skill tracking but doesn't fully address how the scheduling
algorithm adapts per axis. The SM-2 engine currently operates on a single
`UserLearning` record. With multi-axis, does each axis maintain its own SRS
schedule? Do they share one? This is the core of the existing app and the
decision warrants its own ADR. #237 resolves this and produces ADR 0003
superseding ADR 0002.

### 6. Content quality and moderation pipeline → #238

#229 (grammar exercises) and #231 (narrative stories) both produce AI-generated
content shown to users. There is no review/approval workflow. This is a quality
and safety risk, particularly for narrative content that could be off-topic or
linguistically incorrect.

---

## What to revise

### #142 — closed as superseded by #223 ✓

Tatoeba is now listed as a content source candidate in #223. #142 closed.

### #146 and #225 — shared makemeahanzi import pipeline ✓

Both issues updated to mandate a single shared `rake makemeahanzi:download`
task. `rake radicals:import` (#146) and `rake stroke_order:import` (#225)
consume from that shared download.

### #222 hard dependency — prerequisite notices added ✓

Explicit prerequisite blocks added to #223, #227, #228, #229, #230, #231.

### #230 and #231 — sequencing contingency notes added ✓

Both issues updated to state they must not begin until #223 and #229 have
shipped and produced observable skill signal.

---

## Recommended sequencing

Rough priority order, grouped by layer:

**Now (foundations):**
1. #215 — fix keyboard shortcut bug (quick win)
2. #222 — multi-axis skill architecture (everything depends on this)
3. #221 — Playwright MCP for Claude debugging (developer tooling; helps all subsequent work)
4. Learner dashboard (missing issue — create next)
5. LLM + audio infrastructure (missing issues — create next)

**Layer 2 data enrichment (can run in parallel once #222 is shipped):**
6. #226 — dictionary hierarchy + CC-CEDICT de-prioritisation
7. #224 — pronunciation audio
8. #225 + #146 — stroke order + radical breakdown (shared import)
9. #206 — SUBTLEX-CH frequency data

**Layer 3 practice modes (after #222 and dashboard):**
10. #219 — stable flashcard UI
11. #223 — graded reading
12. #227 — remedial learning
13. #229 — grammar assessment
14. #228 — voice input (Phase 1: phonetics only)

**Layer 4 AI practice (after Layer 3 validates engagement):**
15. #220 — MCP server
16. #230 — voice-to-voice dialogue
17. #231 — interactive narrative

**Layer 5 (after the core loop is proven):**
18. #232 — teacher mode

---

## Issue index — April 2026 session

| # | Title | Layer |
|---|---|---|
| #219 | Stable fixed-height flashcard UI with adaptive font scaling | 3 |
| #220 | MCP server exposing learning state for AI-driven contextual practice | 4 |
| #221 | Playwright MCP for Claude frontend debugging | infra |
| #222 | Multi-axis skill architecture | 2 |
| #223 | Graded reading with inline click-to-reveal | 3 |
| #224 | Pronunciation audio playback | 1 |
| #225 | Stroke order diagrams | 1 |
| #226 | Multi-source dictionary hierarchy | 1 |
| #227 | Remedial learning mode for struggling characters | 3 |
| #228 | Voice input and pronunciation assessment | 3 |
| #229 | HSK grammar point assessment | 3 |
| #230 | Voice-to-voice dialogue conversations | 4 |
| #231 | Branching interactive narrative mode | 4 |
| #232 | Teacher mode | 5 |
