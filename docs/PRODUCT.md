# Product

## Vision & Purpose

This app is a reference + learning hub for building and maintaining Chinese Hanzi knowledge over time.

The core problem it targets is the “stop / start” learning pattern: after a break, it’s hard to know:

- What you previously learned but might have forgotten
- What should be re-tested soon (to regain confidence quickly)
- What you never actually learned (false familiarity)

The product’s job is to make resuming easy and efficient by keeping an honest learning log and turning it into clear next actions.

It should also move the learner toward richer engagement as early as possible without pushing them out of their depth. Flashcards are the foot in the door, not the final destination.

## User

Initially: a single motivated self-learner (me) learning Hanzi as part of broader vocabulary collections (e.g., HSK lessons), using Anki today but wanting more structure and insight than a flashcard app provides.

Over time: other self-learners who want a clear, data-backed view of what they know and what to do next.

## User Needs

- Quickly resume after a gap with minimal frustration
- Understand retention (what “stuck”, what decayed, what was never solid)
- Break “learning a character/word” into trackable aspects (not just “known/unknown”)
- Get targeted help with characters that are visually confusable or persistently “sticky” in the wrong way
- Get study guidance that balances confidence-building and novelty
- Progress from isolated items into text, stories, and other contextual material at an appropriate difficulty level
- Use the dictionary/tag hierarchy (HSK/lessons) to study in collections, not isolated items
- Treat knowledge as a reusable data resource (coverage checks, sharing, inputs to other tools)

## Current Capabilities

Based on the current codebase, the app already supports:

- Dictionary entries with meanings and sources
- Hierarchical tags (e.g., HSK level → lesson)
- Import pipelines for dictionary + HSK tagging
- Import/migration of Anki review history into app models (so the app can reason over review events)

In other words: there’s already enough data to bootstrap a meaningful “learning log” even before adding in-app exercises.

## Feature Ideas

The sections below are ordered roughly from “core product” to “later extensions”.

### Progress & Stats

**Learning log (MVP anchor).** A timeline-backed view of learning per entry and per collection that answers:

- First seen vs last seen
- Review/test history (especially after breaks)
- Confidence trend over time (derived from review outcomes)
- “Regain plan”: a short list of high-leverage items to re-test to get back into flow

**Learning log visualisations (MVP-friendly).** In addition to lists/timelines, a compact “map” view can make the state obvious at a glance. One useful pattern is a 2-axis plot where:

- X-axis: progress toward mastery (left = new/fragile, right = stable/mastered)
- Y-axis: review urgency within the current cycle (e.g., bottom = not due/just reviewed, top = due/overdue)

This supports fast decisions after a break: start with the “top-left” (fragile + due) to regain traction, and periodically sample “top-right” (stable + due) to prevent silent decay.

**Stop/start recovery views.** When returning after a gap, show:

- Items likely forgotten (high value, high decay)
- Items likely retained (quick wins)
- Items never solid (need re-teach, not just re-test)

**Collection dashboards.** Per HSK/lesson/tag:

- Coverage (seen / learning / mastered)
- Recommended next slice (small, consistent goals)

### Study Guidance

**Study suggestions driven by the log.** Given time available (5, 15, 30 minutes), propose a session that mixes:

- Confidence rebuild (retained items)
- Consolidation (currently learning)
- A small amount of new material

**Break-aware sessions.** If last activity was a while ago, bias toward diagnostic testing and reactivation.

**Progressive richness.** The product should aim to get the learner into richer material quickly, while staying within measurable comprehension. That means:

- Start with isolated review when necessary
- Move into short phrases and example sentences early
- Progress toward dialogues, short texts, and stories once coverage is sufficient
- Use the learner model to keep contextual material challenging but not overwhelming

### Dictionary

**Fast lookup and cross-linking.** Treat the dictionary as the canonical reference layer and ensure learning views link back to:

- Meanings, pinyin, sources
- Tag hierarchy placement (HSK/lesson)
- Related characters/words (later)

### Anki Integration

**Bootstrap from Anki, but don’t be constrained by it.** Use Anki imports to:

- Seed what the user has seen and how it performed historically
- Provide an honest baseline for the learning log

Longer term, Anki becomes one input among others (in-app exercises, writing practice, etc.).

### Knowledge as Data

**Expose “what I know” as a data product.** The learning log should be queryable and composable, not just a personal display. Examples:

- Article coverage: “What % of characters/words in this text are mastered/learning/new?”
- Targeted generation: ask an LLM to produce a dialogue using ~60% mastered, ~20% learning, and a few new items
- Contextual progression: choose or generate reading material that stretches the learner without dropping them into incomprehensible content

The product value is controllability and honesty — generated or selected content constrained by _measured_ familiarity, not guesswork.

These features depend on a solid learning log and stable definitions of “known/learning/new”, so they are later-stage but worth designing toward from the start.

### Social & Sharing

**Shareable progress summaries.** Examples:

- Shareable summaries (by HSK level, by lesson)
- A public “profile” view of coverage (optional, privacy-first)
- Export formats (later) so other tools can consume the learning state

### Curriculum

**Collections as first-class.** HSK (and other curricula later) should feel like:

- A navigable learning path
- A stable set of collections you can pause and resume
- A source of meaningful progress measurement

**Axis-based learning model (future).** Break down the idea of “learning a character/word” into separate aspects (axes). For example:

- Meaning/translation recognition
- Pronunciation (pinyin + tones)
- Usage (can use in a sentence)
- Writing/production (can write it)
- Decomposition (can break into components/radicals)
- Etymology/pictogram awareness (if relevant)

The goal is not to overcomplicate the UI, but to let the app be honest about _what kind_ of knowledge is strong vs weak.

In practice, “I know this character” can mean several different things, and the app should avoid collapsing them too early.

**Useful meaning of “know” for Hanzi.** A learner may know a character at one or more of these levels:

- Visual recognition: “I recognise this character when I see it.”
- Meaning recognition: “I can connect this character to one or more meanings.”
- Reading recall: “I know how it is pronounced, including tone, in this context.”
- Form recall: “Given a prompt, I can produce or write the character.”
- Structural understanding: “I can break it into components/radicals and distinguish it from similar-looking characters.”
- Contextual usage: “I understand how it behaves in words/sentences and can interpret or choose it correctly in context.”

These are related, but they are not interchangeable. For example:

- A learner may recognise 妈 and know it means “mother”, but forget the tone.
- A learner may know 好 in familiar words, but be weak at producing it from memory.
- A learner may know a character in isolation, but not know which compounds it commonly appears in.

That means the app should treat “knowing” as a profile, not a binary state.

**Recommended axes.** For product purposes, the axes can be framed as:

- Form: can I visually identify the character and tell it apart from confusable neighbours?
- Meaning: can I map the character to the right meaning(s)?
- Sound: can I recall the pronunciation and tone for the intended reading?
- Production: can I write/type/produce it from a semantic or phonetic prompt?
- Composition: can I decompose it into useful parts and use that to aid memory?
- Usage: can I understand or select it correctly inside a word or sentence?

**Not all axes are equal.** Some are more foundational than others:

- Recognition is weaker than recall.
- Recall is weaker than production in context.
- Isolated knowledge is weaker than contextual knowledge.
- Stable knowledge over time is stronger than recent short-term success.

So “mastered” should be a stronger claim than “usually recognise it in flashcards”.

**A practical product definition.** For this app, a character is probably only “mastered” when the learner can do the following reliably enough over time:

- Recognise it quickly
- Recall at least the primary meaning
- Recall the expected pronunciation for the studied context
- Distinguish it from close visual confusions
- Demonstrate that ability after spacing, not just immediately after study

Writing, decomposition, and sentence production are still valuable, but they may be better treated as optional or higher-level mastery dimensions rather than universal requirements for the first version.

**MVP recommendation.** Keep the first implementation narrow and measurable. For Hanzi/word tracking, start with:

- Meaning
- Sound
- Recognition vs recall strength
- Retention over time

Then add later axes when the app can test them directly:

- Composition/decomposition
- Writing/production
- Sentence usage

This keeps the initial learning log honest without overfitting to an overly academic model of knowledge.

This likely requires in-app testing (not only Anki imports) so each axis can be directly exercised and logged.

**Confusion-focused study (future).** Some items need a different intervention than ordinary spaced review. The app should detect characters the learner repeatedly confuses or hesitates on, then offer a dedicated remediation mode that:

- Puts commonly confused characters side by side
- Breaks each character into components, radicals, or distinctive strokes
- Surfaces a memorable differentiator or mnemonic hook
- Tests the distinction directly, not just the character in isolation

This is especially useful for visually similar characters, overlapping radical patterns, and items that the learner consistently maps to the wrong peer. It connects directly to the Form and Composition axes above.

**Exercise framework (future).** A small set of exercise types that feed the learning log, such as:

- Recognition: show Hanzi → pick meaning
- Recall: show meaning → type Hanzi (or pick from options)
- Listening/pronunciation: show Hanzi → choose pinyin+tone (or vice versa)
- Usage: cloze sentence / choose correct word
- Decomposition: pick components/radicals
- Confusion drills: distinguish a target character from commonly confused peers
- Mnemonic/decomposition review: explain or reconstruct why a character differs from a similar one

## What We're Not Building

- A general-purpose “everything app” for Chinese (keep scope anchored to Hanzi/vocab learning)
- A full Anki replacement (at least initially)
- Gamification-heavy features as a substitute for accurate progress tracking
- Premature multi-user/community complexity before the core learning loop works
- Traditional Chinese support in v1 — Simplified only for now, but the data model should not foreclose it (see [docs/research/script-support.md](research/script-support.md))

## Open Questions

### Decide before building core features

- **Mastery definition** — what counts as “mastered” per entry, and how should it decay over time? See [docs/research/mastery-definition.md](research/mastery-definition.md)
- **Axis rollup** — how should multiple axes combine into an overall state (if at all)? See [docs/research/axis-rollup.md](research/axis-rollup.md)
- **MVP axes** — which axes matter for the first version? See [docs/research/mvp-axes.md](research/mvp-axes.md)
- **Exercise types** — which exercise types are highest leverage and simplest to implement first?

### Decide when relevant

- **Script support** — how should the Form axis handle Traditional vs Simplified when Traditional is added? See [docs/research/script-support.md](research/script-support.md)
- **Polysemy** — how should we handle characters with multiple meanings or readings?
- **Privacy** — do we want any sharing by default, and what is opt-in?
- **LLM integrations** — what inputs/outputs are acceptable, and how do we evaluate usefulness?

## Success Metrics (Personal)

- Time-to-resume after a break drops (minutes, not days)
- Fewer “I thought I knew this” surprises (better calibration)
- Steady progress through collections (HSK/lessons) without stalls
- Ability to explain “what I know” with data (coverage, trends)
