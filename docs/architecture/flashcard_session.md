# Flashcard Session Design

## Status

Accepted — April 2026

## Context

The app stores vocabulary, learning states, and review history (migrated from Anki), but
has no in-app testing capability. The next step is a basic flashcard review loop: show a
character, reveal the answer, rate recall quality, update the learning record.

Three decisions needed to be made before implementation:

1. Which spaced repetition algorithm to use
2. How a session's card queue is composed
3. Where session state is held

The existing schema (`user_learnings`, `review_logs`) is already shaped around the Anki
SM-2 algorithm — `ease` (1–4), `factor`, `interval`, `next_due`, `last_interval` — so
the algorithm choice is largely already implied by the data model.

## Decisions

### 1. Algorithm: simplified SM-2 (day-level intervals)

We implement a simplified version of SM-2, not a full Anki replication.

**Key divergence from Anki: no minute-level learning steps.**

Anki's default learning steps are `1 min → 10 min → graduate`. These work in a desktop
app where a study session can span 30+ minutes in one sitting. A web app cannot assume
the user stays open between cards at minute-level intervals. Implementing minute-level
steps would mean cards become overdue within the same session and would require polling
or websockets to surface them — significant complexity for marginal gain.

**Decision: all intervals are day-level. Again resets to 1 day.**

This is a conscious product decision, not an oversight. It means the app is not a
drop-in Anki replacement, but it is honest about what it can test given a web session
model. Review data imported from Anki is fully compatible — the fields map cleanly.

#### Ease button mapping

| Button | Ease value | Meaning |
|--------|-----------|---------|
| Again  | 1 | Incorrect or completely forgotten |
| Hard   | 2 | Correct but significant effort |
| Good   | 3 | Correct with reasonable effort |
| Easy   | 4 | Immediate, confident recall |

#### Interval and factor calculation

Starting values for new cards: `last_interval = 1`, `factor = 2500`.

| Ease   | New interval                                  | Factor adjustment     | State change |
|--------|-----------------------------------------------|-----------------------|--------------|
| Again  | 1 day                                         | max(1300, factor−200) | → learning   |
| Hard   | max(1, last\_interval × 1.2)                  | max(1300, factor−150) | unchanged    |
| Good   | max(1, last\_interval × factor ÷ 1000)        | unchanged             | advance¹     |
| Easy   | Good interval × 1.3 easy bonus               | factor + 150          | → mastered   |

¹ **State advancement on Good:**
- `new` → `learning` on first Good or Easy
- `learning` → `mastered` on second consecutive Good or Easy (approximated by
  `last_interval >= 2` after calculation — i.e. the card has graduated beyond the
  minimum 1-day re-learning interval)

The `SpacedRepetition::SM2` service is a pure function: it takes a `UserLearning` and
an ease integer, and returns new scheduling attributes. It has no side effects. The
caller is responsible for persisting and writing the `ReviewLog`.

### 2. Session composition

A session is a fixed-size ordered queue of `UserLearning` records. Cards are selected
in the following priority order:

1. **Overdue learning cards** — `state = 'learning'` AND `next_due <= now`
   These are cards already in progress that have become due. Prioritised because
   letting them slip back costs more effort to recover than keeping them moving.

2. **New cards** — `state = 'new'`, ordered by `created_at` (oldest first), capped
   at `new_cap` (default: 5 per session). The cap prevents a single session from
   flooding with new material before prior learning is consolidated.

3. **Due mastered cards** — `state = 'mastered'` AND `next_due <= now`
   Spot checks on vocabulary previously brought to mastery. Fill remaining slots
   after the above two buckets.

4. **Fallback** — if the queue is still below `size` after the above, draw additional
   new cards to fill. This handles the common early-stage case where most vocabulary
   is `new` and little is in progress.

**Session size: 20 cards (hard-coded for MVP).** Per-user configuration is a separate
later issue.

An empty queue (no cards due, no new cards) is a valid state. The caller surfaces a
"nothing due" message with the time of the next due card.

### 3. Session state persistence: Rails session cookie, no DB model

Session state (the ordered queue of `user_learning_id`s, current index, and session
start time) is held in the Rails session cookie. No `LearningSession` database model
is introduced for MVP.

**Rationale:** This is a single-user personal app. The cookie approach is simple,
requires no migration, and is sufficient for the review loop and summary screen.
Post-session stats are derived from `ReviewLog` records created during the session,
filtered by `user_id` and `created_at` within the session window (start time stored
in the cookie).

**Future:** If session history, streak tracking, or analytics become important, a
`LearningSession` model can be introduced then. The `ReviewLog` data will still be
fully intact to backfill it.

## Consequences

- The `SpacedRepetition::SM2` service and `LearningSession::Composer` service are
  implemented as pure Ruby objects, fully unit-testable without Rails.
- The `UserLearning` model gains `due`, `overdue_learning`, and `due_mastered` scopes.
- No new database tables are introduced for the MVP review loop.
- The review loop produces one `ReviewLog` record per card rated, which is the source
  of truth for all post-session stats.
- Anki-imported `ReviewLog` records are unaffected — the algorithm runs forward from
  whatever state the migration left.
- Users who previously used Anki at minute-level step granularity will find the first
  few reviews for in-learning cards land on 1-day intervals rather than same-day
  re-tests. This is an acceptable regression given the web session model.
