# Mastery

Derives two independent, read-only facets of a `UserLearning`'s history —
**Coverage** (where a word sits right now) and **Trajectory** (the shape of
its history) — as proposed in
[#391](https://github.com/huwd/learn_hanzi/issues/391). Neither facet
changes the SM-2 scheduler or the `state` column; both are computed from
existing data.

## Coverage

`Unseen → Emerging → Developing → Established`, with `Suspended` as a
manual override outside the sequence.

| Bucket | Rule |
|---|---|
| `Suspended` | `state == "suspended"` |
| `Unseen` | zero reviews |
| `Established` | `first_mastered_at` present (has graduated at least once — durable, not cleared on lapse) |
| `Emerging` | review count < `EMERGING_TO_DEVELOPING_REVIEW_COUNT` |
| `Developing` | review count ≥ `EMERGING_TO_DEVELOPING_REVIEW_COUNT`, never graduated |

## Trajectory

`Stable / Recovering / Chronic / Stalled`, only meaningful for the
`Developing` + `Established` population — a word needs enough history
before its trajectory means anything.

| Bucket | Rule |
|---|---|
| `Chronic` | `graduation_count >= CHRONIC_MIN_GRADUATIONS` — graduated and relapsed more than once |
| `Recovering` | graduated exactly once, currently lapsed (`state != "mastered"`) — hasn't relapsed a second time (yet) |
| `Stalled` | never graduated, review count ≥ `STALLED_MIN_REVIEW_COUNT`, and the average ease over the last `STALLED_LOOKBACK_REVIEWS` reviews is ≤ `STALLED_MAX_RECENT_AVERAGE_EASE` |
| `Stable` | everything else: graduated once and still mastered, or still Developing but not flat/declining |

## Where the thresholds came from

Derived on 2026-07-12 from a real export of one user's 5,493-word
learning history (`user_learnings` + full `review_logs`), not guessed in
the abstract, per the issue's explicit requirement. Method: replay each
word's `review_logs` in review-timestamp order through the same
new → learning → mastered transition table `SpacedRepetition::SM2#calculated_state`
uses, recording (a) the review index of the first `learning → mastered`
crossing, and (b) the total number of such crossings.

**`EMERGING_TO_DEVELOPING_REVIEW_COUNT = 5`**

Review count at first graduation, across all 1,317 words that ever
graduated: median 2, 90th percentile 5. So 90% of everything that ever
graduates does so within 5 reviews — a word past that without graduating
has moved from ordinary early-stage noise into something worth tracking
separately. This also keeps the issue's own illustrative example ("a word
with 3 reviews and low ease is normal Emerging noise") inside `Emerging`,
not `Developing`.

**`CHRONIC_MIN_GRADUATIONS = 2`**

Taken directly from the issue text, not re-derived. Sanity-checked
against the real data: 603 of 1,317 ever-graduated words (46%) have
graduated ≥2 times — a large, meaningful population, confirming this
isn't a rare edge case worth ignoring.

**`STALLED_MIN_REVIEW_COUNT` / `STALLED_LOOKBACK_REVIEWS` / `STALLED_MAX_RECENT_AVERAGE_EASE`**

Checked against the 29 words in the real dataset that were `Developing`
(≥5 reviews, never graduated): every one of them had a last-3-review
average ease ≤ 1.5 (most were long streaks of ease=1 "Again", e.g. a
word with 47 reviews and 46 of them rated "Again"). Two candidate rules
(last-review ease == 1; last-3-review average ≤ 1.5) produced identical
results on the real data — the average was kept since it tolerates a
single recent good rating without immediately reclassifying a word that
may be turning around.

## Re-deriving after real usage changes

If review-count/ease distributions shift meaningfully (e.g. after many
more months of data, or if SM-2's parameters change), re-run the same
replay analysis against a fresh export rather than adjusting these
numbers by feel. The methodology above is the reproducible part; the
numbers in this file are a snapshot of one point-in-time analysis.
