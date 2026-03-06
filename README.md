# learn_hanzi

A Rails 8 app for tracking Chinese vocabulary (HSK) learning progress using Anki review history.

The core idea: take a user's Anki flashcard collection and a Chinese dictionary (CC-CEDICT), combine them, and display HSK vocabulary grouped by learning state:

- **Mastered** — well-established characters reviewed many times
- **Learning** — characters seen but not yet reliably recalled
- **Struggling** — characters with a high lapse rate
- **Not started** — characters in the HSK list not yet studied

## Requirements

- Ruby 4.0.1 (see `.ruby-version`)
- SQLite3
- An Anki collection export (`.colpkg` file) — optional, but needed for learning history

## Setup

```bash
bundle install
bin/rails db:schema:load
```

### Import the dictionary

Download and import [CC-CEDICT](https://www.mdbg.net/chinese/dictionary?page=cc-cedict):

```bash
bin/rails dictionary_download:cc_cedict
bin/rails dictionary_import:cc_cedict
```

### Import HSK vocabulary tags

```bash
bin/rails tag_download:hsk
bin/rails tag_import:hsk_2
bin/rails tag_import:hsk_3
```

### Add custom dictionary entries

A small number of HSK vocabulary items are not present in CC-CEDICT (multi-character phrases, erhua variants, modern terms). A curated set is included:

```bash
bin/rails dictionary_import:custom_entries
```

### Connect your Anki collection

Export a backup from Anki (`File → Export → Anki Collection Package`) and unzip it:

```bash
unzip -o your_collection.colpkg collection.anki21 -d tmp/anki/
```

The app reads the Anki SQLite file directly as a second, read-only database connection. The path is configured in `config/database.yml` (`tmp/anki/collection.anki21` for development).

> **Note**: the Anki connection is marked `database_tasks: false` so Rails migration commands cannot overwrite your collection file.

### Migrate Anki history into the app

```bash
bin/rails anki:migrate_to_models[your@email.com]
```

This reads cards and review logs from the Anki collection and writes `UserLearning` and `ReviewLog` records into the primary database. It is safe to re-run — all imports are idempotent.

The migration targets the deck named `Mandarin: Vocabulary::a. HSK` and also picks up cards temporarily moved to Custom Study Sessions (via Anki's `odid` field).

## Running the app

```bash
bin/rails server
```

Create an account at `http://localhost:3000/sign_up`.

## Running the tests

```bash
bundle exec rspec
```

The test suite uses a self-contained Anki test database built from in-memory seed data — no real Anki file is required.

## Architecture

The app uses two SQLite databases simultaneously:

| Connection | Purpose | File |
|------------|---------|------|
| `primary` | Main app data (dictionary, users, learning records) | `storage/development.sqlite3` |
| `anki` | Read-only connection to an Anki collection | `tmp/anki/collection.anki21` |

### Data model

- **DictionaryEntry** — a single Chinese character or phrase. Has many `Meaning`s and `Tag`s.
- **Meaning** — an English translation with pinyin and a `Source` (e.g. CC-CEDICT or learn_hanzi).
- **Tag** — hierarchical (self-referential). Used to organise vocab by HSK level and lesson.
- **UserLearning** — join between a `User` and a `DictionaryEntry`, with state (`new`, `learning`, `mastered`, `suspended`) migrated from Anki card queue values.
- **ReviewLog** — individual review events migrated from Anki, linked to a `UserLearning`.

### Anki models

`Anki::DB` is an abstract ActiveRecord base that connects to the Anki SQLite. `Anki::Note`, `Anki::Card`, and `Anki::Revlog` are read-only models on top of it. `ReadOnlyRecord` (`app/models/read_only_record.rb`) raises on any write attempt.

## Linting and security

```bash
bin/rubocop              # lint
bin/brakeman --no-pager  # security scan
```

## Contributing

Issues and pull requests welcome. See `CLAUDE.md` for development conventions (commit format, branching, TDD workflow) and `docs/DEVELOPMENT.md` for the project's early development history.
