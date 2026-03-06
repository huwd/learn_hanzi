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
  DECK_ID    = "1"
  DECK_NAME  = "Mandarin: Vocabulary::a. HSK"
  MODEL_ID   = "1234567890"
  MODEL_NAME = "HSK"
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
    }
  ].freeze
  # rubocop:enable Layout/ExtraSpacing

  # One card per note, each exercising a different queue state.
  # did matches DECK_ID; other fields use realistic Anki defaults.
  CARDS = [
    { id: 1, nid: 1, queue:  2, due: 1_234_567_890 },
    { id: 2, nid: 2, queue:  2, due: 1_234_567_890 },
    { id: 3, nid: 3, queue:  0, due: 0             }, # new cards use ordinal position as due
    { id: 4, nid: 4, queue:  1, due: 1_234_567_890 },
    { id: 5, nid: 5, queue:  3, due: 1_234_567_890 },
    { id: 6, nid: 6, queue: -1, due: 1_234_567_890 },
    { id: 7, nid: 7, queue: -2, due: 1_234_567_890 },
    { id: 8, nid: 8, queue:  2, due: 1_234_567_890 }  # note 8 has no DictionaryEntry
  ].freeze

  # One review event per card — enough to verify ReviewLog creation.
  REVLOGS = CARDS.map { |c| { id: c[:id], cid: c[:id] } }.freeze
end
