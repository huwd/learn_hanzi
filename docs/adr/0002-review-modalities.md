# Review Modalities

## Status

Accepted — meaning recognition only for MVP; multi-modality deferred

## Context

Chinese character learning has several distinct, independently variable
dimensions of knowledge:

- **Meaning recognition** — see a character, recall its English meaning
- **Tone recognition** — see pinyin, recall correct tones
- **Production** — see a meaning, produce the character (writing/typing)
- **Contextual use** — recognise or produce the character in a sentence
- **Decomposition** — understand the character's radical components

These dimensions diverge in practice. A learner may have solid meaning
recall but poor tone recall for the same character, or vice versa.
Anki's single ease rating (Again/Hard/Good/Easy) conflates all of them
into one signal, which is imprecise — but it ships and it works.

The SM-2 scheduling service operates on a `UserLearning` record. If
multiple modalities are tracked independently, each would require
either its own `UserLearning` record (separate SRS schedule per
modality) or a `review_type` discriminator on the existing record.
`ReviewLog` already has a `log_type` column (carried over from the
Anki data model) which is the natural place to record which modality
a review tested.

## Decision

Ship a single review modality — **meaning recognition** — for MVP.
Routes, controller, and views are built for this one path only.

`log_type` is recorded on every `ReviewLog` from the start (value `0`
= meaning recognition) so future modalities are distinguishable in the
data without a migration.

Routes are intentionally generic (`/review`) rather than modality-
specific (`/review/recognition`) because:

1. Routes are cheap to change before any external links exist.
2. Locking in a URL structure for hypothetical future modalities would
   be speculative — the right decomposition isn't clear yet.

When a second modality is added, the routing, controller structure,
and SRS model can be revisited with concrete requirements.

## Consequences

- The review UI tests and expresses only meaning recognition.
- `ReviewLog#log_type` is populated from day one; analytics can
  distinguish modality even before the UI supports selection.
- Future modalities will require a considered decision about whether
  to share a `UserLearning` record (blended schedule) or maintain
  separate records (independent schedules per modality). That choice
  should produce its own ADR.
- The `/review` path may eventually become a modality selector, or
  modalities may live at separate paths — deferred until the second
  modality is actually built.
