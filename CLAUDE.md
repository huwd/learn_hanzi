# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run all tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/models/dictionary_entry_spec.rb

# Lint
bin/rubocop

# Start dev server
bin/rails server

# Database setup
bin/rails db:schema:load
bin/rails db:migrate

# Security scan
bin/brakeman --no-pager
```

## Commit Standards

The project adheres to **Conventional Commits** format with these requirements:

**Format**: `<type>[optional scope]: <description>`

Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`

**Subject line rules**:
- Maximum 50 characters
- No trailing period
- Imperative mood ("Add feature" not "Added feature")
- Breaking changes marked with `!` before colon (e.g., `feat!:`) or via `BREAKING CHANGE:` footer

**Message body requirements**:
- Separated from subject by blank line
- Wrapped at 72 characters
- Must answer: Why is this necessary? How does it address the issue? What side effects exist?
- Emphasise the *why* — the code shows *how*, but rationale requires explicit capture
- Document alternatives considered if choosing approach A over B

**Structure principles**:
- Each commit should be a self-contained logical unit (avoid needing "and" in subject)
- Order commits to tell a coherent narrative through repository history
- Revise history on feature branches before opening pull requests

## Branching

**Always work on a branch — never commit directly to `main`.**

Branch naming convention: `<type>/<issue-number>-<short-description>`

```bash
# Example for issue #38
git checkout -b fix/38-ci-rspec-not-running

# Example for issue #22
git checkout -b chore/22-upgrade-rails-8-1
```

Valid prefixes match the commit types: `fix/`, `feat/`, `chore/`, `ci/`, `test/`, `docs/`, `refactor/`.

When the work is complete, push the branch and open a PR against `main`:

```bash
git push -u origin <branch-name>
gh pr create --base main
```

## Development Workflow (TDD)

New feature development follows a test-driven cycle with commits between stages:

1. **Write tests (red phase)** — Add failing specs for the behaviour. Verify `bin/rubocop` passes while `bundle exec rspec` fails. Commit and push.

2. **Implement (green phase)** — Add the implementation. Verify `bundle exec rspec` and `bin/rubocop` both pass. Commit and push.

3. **Refactor** — Clean up with tests still green. Commit and push.

**Note**: Feature branch history can be soft-reset and re-committed before PR submission to align with commit standards.

## Architecture

This is a Rails 8 app for learning Chinese Hanzi (characters). The core purpose is to display a user's HSK vocabulary progress by combining a Chinese dictionary with their Anki flashcard review history.

### Dual Database Setup

The app uses two SQLite databases simultaneously (configured in `config/database.yml`):

- **primary** — the main app database (`storage/development.sqlite3`)
- **anki** — a read-only connection to an Anki flashcard collection file (`.anki21` format, which is SQLite)

The `Anki` module in `app/models/anki.rb` defines `Anki::DB < ReadOnlyRecord` which connects to the anki database, with `Anki::Note`, `Anki::Card`, and `Anki::Revlog` as its models. `ReadOnlyRecord` (`app/models/read_only_record.rb`) enforces read-only access.

In development, the anki database path points to a local Anki backup file. In test, it uses `storage/anki-test.sqlite3`, which is created fresh before the test suite runs via `AnkiHelper.recreate_test_db!` (defined in `spec/support/anki_helper.rb`).

### Data Model

- **DictionaryEntry** — a single Chinese character or phrase (`text` field). Has many `Meaning`s and `Tag`s (via `DictionaryEntryTag`).
- **Meaning** — an English translation of a `DictionaryEntry`, with `pinyin`, `language`, and a `Source`.
- **Source** — provenance of dictionary data (e.g. CC-CEDICT).
- **Tag** — hierarchical (self-referential `parent_id`). Used to organise vocab into HSK levels and lessons (e.g. "HSK 2.0 > HSK 4 > Lesson 1").
- **UserLearning** — join between `User` and `DictionaryEntry`, with a `state` (`new`, `learning`, `mastered`, `suspended`) and scheduling metadata.
- **ReviewLog** — individual review events migrated from Anki, linked to a `UserLearning`.

### Data Import Pipeline

Dictionary and tag data are loaded via Rake tasks:

- `rake dictionary_download:cc_cedict` — downloads CC-CEDICT
- `rake dictionary_import:cc_cedict[file_path]` — parses CC-CEDICT and populates `DictionaryEntry` + `Meaning` records
- `rake tag_download:hsk` — downloads HSK word lists
- `rake tag_import:hsk` — tags dictionary entries with HSK hierarchy
- `rake anki:migrate_to_models[email]` — migrates cards/revlogs from the connected Anki DB into `UserLearning` and `ReviewLog` for a given user

Import helpers live in `app/helpers/` (e.g. `DictionaryImportHelper`, `TagImportHelper`). Import errors are logged to `log/dictionary_import_errors.log`, `log/tag_import_errors.log`, and `log/anki_migration.log`.

### Test Setup

Tests use RSpec with FactoryBot and Shoulda Matchers. The test suite recreates the Anki test database from scratch before each run (`AnkiHelper.recreate_test_db!` in `spec/rails_helper.rb`). The `decks` column in the Anki `col` table is a JSON blob; the test helper (`spec/support/anki_helper.rb`) seeds it with a minimal HSK model structure.

Authentication helpers for request specs are in `spec/support/authentication_helpers.rb`.

### Authentication

Rails 8's built-in authentication generator was used (`bin/rails generate authentication`). Session management is in `app/controllers/concerns/authentication.rb`.
