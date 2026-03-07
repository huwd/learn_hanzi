# Script Support (Traditional vs Simplified)

## Question

Should the app support both Traditional and Simplified Chinese scripts, and if so, how should the data model and learning axes handle the difference?

## Why this matters

Traditional and Simplified Chinese share most of their vocabulary, pinyin, and meaning — but differ in glyph form for a significant subset of characters (~2,300 of the most common). This affects stroke patterns, radical breakdowns, and visual recognition. Getting the architecture wrong early (e.g. treating script as a pure display concern) could make it hard to accurately track form-level learning for learners who switch scripts or study both.

## Key observations

**Most of the dictionary is script-neutral.** CC-CEDICT already stores both a Traditional and a Simplified field per entry. For ~2,300 characters the two forms differ; for the remaining common characters they are identical. So the underlying data (meanings, pinyin, usage) is shared across scripts for all entries.

**The Form axis is script-specific.** Recognising 愛 and recognising 爱 are different skills — different strokes, different radical structures. So:

- Meaning, sound, usage, composition-as-concept → script-agnostic
- Form recognition, stroke production, radical breakdown → script-specific

This suggests the Form axis (and possibly Composition) may need a script scope — e.g. `form:simplified` vs `form:traditional` — rather than being a single undifferentiated score per entry.

**A learner switching scripts hasn't forgotten meaning, but Form progress resets.** The learning record can live on a shared `DictionaryEntry`, but form-level axis scores need to know which script was being tested.

## Options under consideration

- **View-layer only** — store both forms in `DictionaryEntry`, user sets a script preference, display switches accordingly. Form axis treated as a single score (ignores script distinction). Simple, but inaccurate for learners who cross between scripts.
- **Script-scoped Form axis** — the Form (and possibly Composition) axis stores a per-script score. All other axes remain shared. More accurate; adds some data model complexity.
- **Separate entries per script** — Traditional and Simplified are distinct `DictionaryEntry` records linked by a relationship. Most flexible; most complex; probably overkill.

## Decision

Traditional Chinese is **out of scope for v1**. The first version will target Simplified only.

However, the data model should not foreclose Traditional support. Concretely:

- CC-CEDICT import should preserve the Traditional field on `DictionaryEntry` even if it is not surfaced in the UI yet
- The Form axis should be designed with the awareness that it may need a script dimension later — avoid hardcoding assumptions that Form is a single global score per entry
- User script preference (Simplified / Traditional) should be a first-class user setting when Traditional is added, not a global app constant
