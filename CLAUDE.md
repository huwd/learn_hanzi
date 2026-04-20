# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Frontend debugging with Playwright MCP

`.claude/settings.json` wires up `@playwright/mcp` so Claude can navigate the running app, take screenshots, read the DOM, and check JS console output.

### One-time setup

Install the Chromium build that matches the pinned `@playwright/mcp` version:

```bash
npx -p @playwright/mcp@0.0.70 playwright install chromium
```

When upgrading the version in `.claude/settings.json`, re-run this command to keep the browser in sync.

### Workflow

1. Start the dev server: `bin/rails server`
2. **Authenticate first (headless-safe)** — `@playwright/mcp` runs headless, so do not rely on manually completing OIDC in a visible browser window. Use one of these approaches instead:
   - Reuse a pre-authenticated browser/storage state if one has already been prepared for local debugging.
   - Or navigate to `http://localhost:3000/sign_in` with MCP and drive the OIDC flow via MCP actions, validating progress with `browser_take_screenshot`, `browser_snapshot`, and `browser_console_messages`.
   The authenticated session cookie persists for subsequent Playwright navigations in the same browser context.
3. Navigate to the relevant route and use `browser_take_screenshot`, `browser_snapshot` (accessibility tree), or `browser_console_messages` to inspect state.

### Key routes for UI verification

| Flow | Routes |
|---|---|
| Learn | `/learn` → `/learn/card` → `/learn/review` → `/learn/summary` |
| Review | `/review` → `/review/card` → `/review/summary` |
| History | `/review/history` |

### Stimulus controllers

- `card_flip_controller.js` — handles card reveal and keyboard shortcuts (1–4 ease keys) on both review flows
- `learn_card_controller.js` — controls the learn card presentation
- `collapsible_controller.js` — show/hide toggles (e.g. supplemental meanings)
- `dropdown_controller.js` — dropdown menus

After any frontend change: navigate to the affected route, take a screenshot, and check `browser_console_messages` for JS errors before marking the task complete.

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

## Pull Request Reviews

Reviews may come from a human, another Claude instance, or a different AI model
(e.g. GitHub Copilot). Treat all reviewer comments with equal rigour regardless
of source.

### Handling comments

1. **Read all comments first** — evaluate every comment together before acting.
   Use the full context of the PR and codebase to judge relevance; don't apply
   suggestions mechanically.

2. **Where you agree** — make the change as an individual, self-contained commit.
   Reply to the comment citing the commit SHA and briefly explaining what was
   done.

3. **Where you disagree** — do two things:
   - Reply on the comment explaining the reasoning for not changing it.
   - Add a **Deliberate decisions** section to the PR description listing the
     choice and the rationale. This prevents the same point being raised again
     in subsequent review rounds.

4. **Resolve all threads** — once every comment has been replied to, resolve
   all threads (including ones where no change was made).

5. **Request re-review** — request a fresh review from every reviewer who left
   a comment. Merge only once that review comes back clean.

### gh API commands for PR comment workflow

```bash
# List inline review comments with IDs
gh api repos/huwd/learn_hanzi/pulls/<PR>/comments \
  --jq '.[] | {id: .id, url: .html_url, body: .body[:80]}'

# Reply to an inline comment (note: /pulls/<PR>/comments/<id>/replies — not /pulls/comments/)
gh api repos/huwd/learn_hanzi/pulls/<PR>/comments/<comment-id>/replies \
  --method POST \
  --field body="Your reply here"

# Resolve a review thread (requires the comment's node_id)
node_id=$(gh api repos/huwd/learn_hanzi/pulls/comments/<comment-id> --jq '.node_id')
gh api graphql -f query="mutation { resolveReviewThread(input: {threadId: \"$node_id\"}) { thread { isResolved } } }"

# Request re-review
gh api repos/huwd/learn_hanzi/pulls/<PR>/requested_reviewers \
  --method POST \
  --field "reviewers[]=<github-username>"
```

### After a clean re-review

Before merging, assess the fix commits produced during review:

- If a fix commit corrects something in an earlier commit on the same branch,
  consider using `git rebase -i` to fixup the fix into the original commit.
  This keeps the branch history clean and linear.
- If the fix is substantive enough to stand on its own (e.g. a genuine bug
  caught in review), leave it as a separate commit so the history explains
  what happened.

Use judgement — the goal is a history that tells a coherent story, not one
that hides real corrections.

## Rails Conventions

**Time zones** — always use `Time.zone.today` or `Time.current` instead of `Date.today` or `Time.now`. `Date.today` and `Time.now` use the system clock and ignore the app's configured time zone, causing off-by-one errors around midnight and in non-UTC environments.

```ruby
# Bad
Date.today
Time.now

# Good
Time.zone.today
Time.current
```

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
