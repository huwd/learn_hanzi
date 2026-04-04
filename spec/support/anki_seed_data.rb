# Structured seed data for the Anki test database.
#
# Each record documents WHY it exists so regression anchors are easy to
# identify and new cases can be added without reading AnkiHelper setup code.
#
# Field order for `flds` (unit-separator \x1F delimited):
#   ID | Simplified | Traditional | Pinyin | Audio | English | Part of Speech | Audio Sentence
#
# To add a regression anchor for a new bug:
#   1. Add a NOTES entry with a clear :purpose string
#   2. Add a matching CARDS entry (same :id)
#   3. Add a matching REVLOGS entry (same :id) if the card should have review history
module AnkiSeedData
  DECK_ID             = "1"
  DECK_NAME           = "Mandarin: Vocabulary::a. HSK"
  FILTERED_DECK_ID    = "2"
  FILTERED_DECK_NAME  = "Custom study session"
  MODEL_ID            = "1234567890"
  MODEL_NAME          = "HSK"
  FIELD_NAMES = [
    "ID", "Simplified", "Traditional", "Pinyin",
    "Audio", "English", "Part of Speech", "Audio Sentence"
  ].freeze

  # Maps Anki queue integers to the UserLearning state they should produce.
  # Mirrors the case/when logic in lib/tasks/anki.rake.
  QUEUE_STATE_MAP = {
     0 => "new",
     1 => "learning",
     2 => "mastered",
     3 => "learning",    # day-learning treated as learning
    -1 => "suspended",
    -2 => "suspended"    # buried treated as suspended
  }.freeze

  SEP = "\u001F"
  private_constant :SEP

  # rubocop:disable Layout/ExtraSpacing
  NOTES = [
    {
      id:      1,
      guid:    "note001",
      sfld:    "好",
      flds:    "20#{SEP}好#{SEP}好#{SEP}hǎo#{SEP}hao3#{SEP}good; well#{SEP}adjective#{SEP}[sound:hao3.mp3]",
      purpose: "queue 2 (mastered) — standard successful import case"
    },
    {
      id:      2,
      guid:    "note002",
      sfld:    "很",
      flds:    "21#{SEP}很#{SEP}很#{SEP}hěn#{SEP}hen3#{SEP}very; quite#{SEP}adverb#{SEP}[sound:hen3.mp3]",
      purpose: "queue 2 (mastered) — second standard import case"
    },
    {
      id:      3,
      guid:    "note003",
      sfld:    "学",
      flds:    "30#{SEP}学#{SEP}學#{SEP}xué#{SEP}xue2#{SEP}to study#{SEP}verb#{SEP}",
      purpose: "queue 0 (new) — card never reviewed, maps to 'new' state"
    },
    {
      id:      4,
      guid:    "note004",
      sfld:    "天",
      flds:    "40#{SEP}天#{SEP}天#{SEP}tiān#{SEP}tian1#{SEP}day; sky#{SEP}noun#{SEP}",
      purpose: "queue 1 (learning) — card in active learning steps, maps to 'learning'"
    },
    {
      id:      5,
      guid:    "note005",
      sfld:    "人",
      flds:    "50#{SEP}人#{SEP}人#{SEP}rén#{SEP}ren2#{SEP}person#{SEP}noun#{SEP}",
      purpose: "queue 3 (day-learning) — should also map to 'learning', not a separate state"
    },
    {
      id:      6,
      guid:    "note006",
      sfld:    "大",
      flds:    "60#{SEP}大#{SEP}大#{SEP}dà#{SEP}da4#{SEP}big#{SEP}adjective#{SEP}",
      purpose: "queue -1 (suspended) — manually suspended by user"
    },
    {
      id:      7,
      guid:    "note007",
      sfld:    "小",
      flds:    "70#{SEP}小#{SEP}小#{SEP}xiǎo#{SEP}xiao3#{SEP}small#{SEP}adjective#{SEP}",
      purpose: "queue -2 (buried) — should map to 'suspended', not a separate state"
    },
    {
      id:      8,
      guid:    "note008",
      sfld:    "不",
      flds:    "80#{SEP}不#{SEP}不#{SEP}bù#{SEP}bu4#{SEP}not#{SEP}adverb#{SEP}",
      purpose: "REGRESSION ANCHOR: no matching DictionaryEntry — import must skip without crashing"
    },
    {
      id:      9,
      guid:    "note009",
      sfld:    "爱",
      flds:    "90#{SEP}爱#{SEP}愛#{SEP}ài#{SEP}ai4#{SEP}to love#{SEP}verb#{SEP}",
      purpose: "REGRESSION ANCHOR: card homed in target deck but currently in a filtered deck " \
               "(did=FILTERED_DECK_ID, odid=DECK_ID) — import must include it via odid"
    }
  ].freeze
  # rubocop:enable Layout/ExtraSpacing

  # Structured collection seed data. Keep values that are persisted to `col`
  # here so constants can derive from the same source and cannot drift.
  COL = {
    crt: 1_234_567_890
  }.freeze

  # Collection creation timestamp stored in col.crt (Unix seconds).
  # Used as the epoch for converting queue=2 "due day" values to real dates.
  COL_CRT = COL.fetch(:crt)

  # One card per note, each exercising a different queue state.
  # Cards default to did=DECK_ID and odid=0. Pass :did and :odid to override
  # (e.g. to simulate a card stranded in a filtered deck).
  #
  # due field semantics by queue:
  #   queue 0       — ordinal sort position (not a date)
  #   queue 1, 3    — Unix timestamp in seconds
  #   queue 2       — days since col.crt  ← IMPORTANT: not a Unix timestamp
  #   queue -1, -2  — inherited from prior queue in Anki; treated as next_due=nil here
  CARDS = [
    { id: 1, nid: 1, queue:  2, due: 300             }, # mastered — 300 days after crt
    { id: 2, nid: 2, queue:  2, due: 300             }, # mastered — 300 days after crt
    { id: 3, nid: 3, queue:  0, due: 3               }, # new — ordinal position, not a date
    { id: 4, nid: 4, queue:  1, due: 1_234_567_890   }, # learning — Unix timestamp
    { id: 5, nid: 5, queue:  3, due: 1_234_567_890   }, # day-learning — Unix timestamp
    { id: 6, nid: 6, queue: -1, due: 1_234_567_890   }, # suspended
    { id: 7, nid: 7, queue: -2, due: 1_234_567_890   }, # buried
    { id: 8, nid: 8, queue:  2, due: 300             }, # no DictionaryEntry — must be skipped
    # REGRESSION ANCHOR: card homed in target deck but currently in a filtered deck.
    # did=FILTERED_DECK_ID means the current migration query (WHERE did=target) misses it.
    # odid=DECK_ID is the only signal that it belongs to the target deck.
    { id: 9, nid: 9, queue: 2, due: 300, did: FILTERED_DECK_ID, odid: DECK_ID }
  ].freeze

  # One review event per card — enough to verify ReviewLog creation.
  REVLOGS = CARDS.map { |c| { id: c[:id], cid: c[:id] } }.freeze
end
