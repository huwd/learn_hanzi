# SRS Learning Profiles: Research Findings

Research for the learning advisor / dashboard narrative feature.
Compiled from Wozniak/SuperMemo primary sources, Anki community documentation,
peer-reviewed papers, and the immersion-learning community (AJATT, Refold, Hacking Chinese).

---

## 1. The Memory Model Underpinning SRS

### SM-2 and the Two-Component Model (Wozniak, 1985)

Piotr Wozniak's SM-2 algorithm — the ancestor of Anki's scheduler — tracks two
variables per card:

- **Retrievability (R)**: the probability of recall at a given moment; decays
  exponentially over time following Ebbinghaus's curve (`R = e^(-t/S)`)
- **Stability (S)**: how slowly R decays; increases with each successful
  retrieval; a more stable memory survives longer gaps between reviews

SM-17 adds a third component:
- **Difficulty (D)**: the ceiling on stability gain per repetition; hard cards
  gain stability more slowly even when recalled correctly

The key insight for a learner advisor: **difficulty is not a fixed property of a
card — it is an emergent one**. Cards that consistently yield low quality scores
develop lower stability ceilings over time. The SM-2 ease factor (`factor` in
our `user_learnings` table) is a direct proxy for D.

### Anki's Card State Taxonomy

| State | Definition |
|---|---|
| New | Never reviewed |
| Learning | Recently introduced; graduating through short intervals |
| Young | Review queue; interval < 21 days |
| Mature | Review queue; interval ≥ 21 days |
| Lapsed / Relearning | Mature card that was forgotten; re-entering learning |
| Suspended / Leech | Removed from scheduling |

The 21-day mature threshold is a convention, not a hard cognitive boundary, but it
is a widely accepted proxy for durable long-term retention. **Mature retention is
the meaningful metric**; young-card retention is inflated by recency.

Our app's state model (`new / learning / mastered / suspended`) maps approximately
as: `new → new`, `learning → young`, `mastered → mature`. We do not currently
distinguish young from mature, which limits some retention analytics.

---

## 2. The Forgetting Curve and Overdue Reviews

### Ebbinghaus (1885)

Without reinforcement, approximately:
- 42% forgotten within 20 minutes
- 56% forgotten within 1 hour
- 79% forgotten within 31 days

The curve is steep initially and flattens over time — the most critical review
window is immediately after initial encoding.

### Wozniak's Stability Increase Insight

Critically: **the lower the retrievability at review time, the larger the
subsequent stability gain** — up to a point. A card that is moderately overdue
but still recalled correctly produces a larger long-term memory boost than one
reviewed exactly on schedule.

However, if the card is so overdue it is forgotten entirely (a lapse), the
interval resets and no stability gain accrues.

Practical implication: mild overdueness is not catastrophic; severe backlog
causing wholesale forgetting is.

### Catching Up: What the Evidence Says

1. **Do not reset**: Wiping a deck discards legitimate memory progress on cards
   that would still be recalled. Community consensus is strongly opposed to resets.
2. **Do not mass-review in a single session**: Cognitive fatigue degrades recall
   quality for later cards in the session; provides no spacing benefit; high
   burnout risk.
3. **FSRS (Anki's current algorithm, adopted Nov 2023) handles overdue cards
   better than SM-2** by accounting for the actual delay when rescheduling.
4. **Recovery strategy**: set daily cap (e.g. 100 reviews/day), suspend
   non-critical material, work through the queue over 2–3 weeks.

Sources: Wozniak (supermemo.guru), Control-Alt-Backspace, MemoForge, Anki forums.

---

## 3. Review Load Distribution and Review Debt

### Sustainable Daily Load (Community Consensus)

| Parameter | Sustainable Range | Notes |
|---|---|---|
| Session length | 15–30 min/day | Beyond this, quality declines |
| Daily reviews | 100–200 cards | Practical ceiling for most learners |
| New cards/day | 10–20 cards | The widely-cited sustainable rate |
| New card multiplier | ~7–10× | Each new card generates ~7–10 reviews in the following month |

At a steady 20 new cards/day, that implies roughly 140–200 reviews/day from
those cards alone once they are in circulation, before accounting for
maturing older material.

### The Abandonment Spiral (Review Debt)

Review debt is self-reinforcing:
1. Learner adds new cards too aggressively
2. Reviews compound faster than they can be cleared
3. The backlog induces dread
4. Sessions are skipped
5. More cards become overdue
6. The backlog is now psychologically and mathematically overwhelming

**The two-week lag effect**: new card intake today does not fully manifest in the
review queue for 2–3 weeks, because initial learning cards must graduate to young
review status first. Learners who add 50 cards/day initially see manageable load,
then face an avalanche at week 3.

Recovery: immediately set new card limit to 0, cap daily reviews at a manageable
number, triage by age (oldest-overdue first), suspend non-essential material.

Sources: Anki forums, MemoForge, Gene Dan (12,000 card backlog recovery).

---

## 4. New Card Pacing

### Academic Evidence

**Cepeda et al. (2006)** — meta-analysis of 317 experiments: the optimal
inter-study interval (ISI) is not fixed; it scales proportionally with the desired
retention interval. For vocabulary retained over months to years, spacing must be
measured in weeks to months.

**Bahrick et al. (1993)** — 13 sessions at 56-day intervals produced retention
comparable to 26 sessions at 14-day intervals. Longer spacing slightly slowed
initial acquisition but substantially improved long-term retention.

### Community Norms

| Learner type | New cards/day | Notes |
|---|---|---|
| Casual learner | 5–10 | Minimise burnout; sustainable indefinitely |
| Dedicated learner | 10–20 | Standard Anki recommendation |
| Intensive period | 20–30 | Short-term acceptable; monitor load |
| Exam prep | 50–100 | Not maintainable long-term |

Matt vs Japan recommends targeting < 1 hour of SRS/day, which works out to
~15–20 new cards for most learners. He also recommends 85% desired retention in
FSRS as maximising total knowledge per unit of review effort.

Refold's guidance: start with 10–15 new cards/day to build the review habit.
**Never add new cards when overdue reviews exceed a comfortable session.**

---

## 5. Leech Cards

### Definition

A leech is a card that has lapsed a threshold number of times (Anki default: 8
lapses) while in the mature/review stage. Lapses during the learning stage do not
count. At the threshold, Anki tags the note and typically suspends it.

### Why They Matter

Olle Linge (Hacking Chinese) reports leeches take **on average 10× as many
repetitions** to learn as non-leeches. A deck with many leeches consumes
disproportionate review time with minimal retention gain.

Common causes in Chinese/Japanese learning:
- **Interference**: similar-looking or similar-sounding characters confusing each
  other (homophones, near-homophones, character shape similarity)
- **Insufficient context**: card too decontextualised; no distinguishing hook
- **Lack of understanding**: memorised without understanding the underlying concept
- **Irrelevance**: material not reinforced in immersion

### Handling Strategies

1. **Suspend and return** when the word is encountered in real context
2. **Redesign the card**: add mnemonic, audio, example sentence, radical breakdown
3. **Add distinguishing context**: minimal pairs for interference leeches
4. **Delete**: if the word is rare or irrelevant, deletion is legitimate (AJATT endorses this)
5. **Reset and restudy**: fresh start via "Forget" in Anki, but requires fixing the underlying difficulty

Leeches > 5–10% of active cards indicate a structural problem that more reviews
will not solve.

---

## 6. Cramming vs Spaced Practice

### Kornell (2009)

Directly tested spacing vs cramming with flashcards:
- Spacing was more effective for **90% of participants**
- Yet **72% believed cramming had been more effective** after the session

The **fluency trap / illusion of fluency**: items reviewed in rapid succession
feel familiar and easily recalled during the session, creating a false sense of
mastery. Learners systematically choose the strategy that *feels* effective
(massed) over the one that *is* effective (spaced).

### Bjork's Desirable Difficulties (1994)

Four conditions that impair short-term performance but improve long-term retention:
spacing, interleaving, retrieval practice, and generation. They are "desirable"
precisely because the effort of retrieval from long-term memory — rather than
recognition from working memory — is what builds durable encoding.

Key statistics:
- Retrieval practice improves long-term recall by ~50% vs restudying
- Meta-analysis of 254 studies: spacing produces 10–30% better retention overall
- Spaced > massed by 100–200% in long-term recall at equivalent total study time

### SRS Dashboard Implication

A learner doing mass cramming sessions (high per-session reviews, infrequent
practice) will display: high same-day review counts, low session frequency, and
likely poor mature card retention. This signature is detectable from review logs.

---

## 7. Observable Thresholds for Learner Phase Classification

No single paper defines universal thresholds, but research and community practice
converge on several operationalisable signals:

### Retention Rate (Mature Cards)

| Mature Retention | Interpretation |
|---|---|
| > 95% | Cards reviewed too frequently; intervals too short |
| 90–95% | Optimal |
| 85–90% | Acceptable; monitor trend |
| 80–85% | Borderline; workload too high or cards too difficult |
| < 80% | Alert: backlog, too many leeches, or insufficient review frequency |

FSRS default target: 90%. Community consensus: 80% is the floor before
corrective action is needed.

### Review Backlog

| Overdue Cards | Interpretation |
|---|---|
| 0–1 day's reviews | Healthy |
| 1–3 days' reviews | Minor slippage; pause new cards |
| 3–7 days' reviews | Significant debt; triage mode |
| > 1 week's reviews | Crisis; suspend non-critical material |

### New Card Rate vs Review Queue Ratio

Heuristic: if daily new cards produce a queue that cannot be cleared within 30
minutes, the new card rate is too high.

### Leech Concentration

> 5–10% of active cards = structural problem that reviewing will not solve.

### Session Frequency

Daily practice is the single most important SRS habit variable. Weekly or less
practice is a strong predictor of backlog and poor retention.

### Composite Learner State Signal

| Learner State | Typical Signals |
|---|---|
| **Healthy / On-Track** | Retention 88–95%; overdue < 1 day's worth; daily sessions; 10–20 new/day; leeches < 5% |
| **Overloaded** | Retention declining; overdue growing; new rate > 25/day; sessions > 40 min |
| **Backlog / Recovery** | Overdue > 3 days' worth; retention < 85%; irregular sessions |
| **Lapsed / Inactive** | No reviews 3+ days; overdue > 1 week's worth |
| **Maintenance** | Retention stable 90–95%; few new cards; short sessions; large mastered proportion |
| **Beginner / Ramp-Up** | Mostly new/learning cards; few mastered; retention data sparse |

---

## 8. Dashboard Feedback: What Motivates vs Demotivates

### Self-Determination Theory (Deci & Ryan)

Three basic psychological needs whose satisfaction predicts sustained motivation:
- **Autonomy**: sense of control over learning
- **Competence**: sense of growing capability
- **Relatedness**: connection to goals

Research on learning analytics dashboards shows that **transparent, actionable
progress information** satisfies the competence need and improves engagement.
However:
- **Informational feedback** (data about mastered cards, retention trends,
  HSK coverage) → supports intrinsic motivation
- **Controlling feedback** (guilt-inducing backlogs, large red warning numbers,
  pressure framing) → undermines autonomy, can trigger amotivation

### Streaks (Duolingo Internal Research)

- Learners reaching a 7-day streak are **2.4× more likely** to continue the
  next day vs streak-less learners
- Streaks work through loss aversion: the longer the streak, the stronger
  motivation not to break it
- Habit formation baseline: **~66 days** (Lally et al., 2010) for a behaviour
  to become automatic (not the commonly-cited 21 days)
- Implication: the first 60–90 days are the critical habit-formation window

### Motivating vs Demotivating Patterns

**Motivating**:
- Cumulative mastered card count (tangible evidence of progress)
- Long-term retention trend (seeing mature retention hold above 90%)
- Cards-per-HSK-level completed (goal proximity, structure)
- Streak / session regularity visualisation
- Projected milestone: "At this pace, you will complete HSK 3 in 45 days"
- Session time per day (shows the cost is manageable)

**Demotivating**:
- Large overdue counts displayed prominently without actionable guidance
- Declining retention rates without explanation or recommendation
- Total cards remaining with no visible progress
- Guilt-oriented framing ("You missed 3 days")
- Demanding unrealistic accuracy (> 97% retention exponentially increases load)

---

## Key Sources

- Wozniak (supermemo.guru): Two-component model, stability increase, forgetting curve
- Ebbinghaus (1885); replication PMC 2015
- Cepeda et al. (2006, 2008) — spacing meta-analysis, PubMed 16719566
- Bahrick et al. (1993) — long-interval spacing, Sage Journals
- Kornell (2009) — cramming vs spacing illusion, Wiley / Williams College
- Bjork (1994+) — desirable difficulties, UCLA Bjork Lab
- Anki Manual — leeches, statistics, deck options
- Control-Alt-Backspace — catching up, leeches
- Hacking Chinese / Olle Linge — leech cost analysis
- Refold / Matt vs Japan — FSRS optimal retention, new card pacing
- FSRS documentation (open-spaced-repetition/fsrs4anki GitHub)
- Lally et al. (2010) — habit formation, 66-day baseline
- Duolingo Engineering Blog — streak research
- Deci & Ryan — Self-Determination Theory; Springer LAD research (2024)
- Gwern.net — Spaced Repetition (comprehensive overview)
