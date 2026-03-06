# Development History

This file preserves the original development journal from the README. It captures
the thinking and decisions made during early development. Current tasks and bugs
are tracked as GitHub issues.

---

## 27th June

Of course I've lost the thread of what I was doing here.

So here's where I see outstanding issues.
Core issue is that having imported my Anki Collection it's managed to import some but not all of my learnings, Characters I know I've mastered are not showing up as learned.

This is the big barrier to progress.

I think the next step is to work out what an appropriately representative test database is, ideally containing a range of characters that I know import well, and also ones that fail.

It should be extensible so I can add future bugs to it. This is likely the core work as it's difficult to track the bug down without further tests.

Additionally we have a few other issues:

### log/dictionary_import_errors.log

This seems to show CEDICT items we've been unable to import.
I suspect this is either genuine duplicates in CEDICT (surely not?), or something about the ways characters repeat in the language. However I'd understood that constraining uniqueness by meaning would sort it...

### log/tag_import_errors.log

These seem to be legitimate errors, ones where CEDICT doesn't have an entry for them, either because they're a turn of phrase or a combination that doesn't appear. These need custom dictionary entries.

They should represent entries from HSK that don't appear in source CEDICT.

Can draw these from HSK materials perhaps?

### log/anki_migration.log

Similarly these would represent:

Anki flashcards with phrases that aren't in CEDICT and need a custom entry.

---

## Wednesday Jan 1st

### Frontend

Now is a good time to start.
Let's build it around the tags. Theory is:

- For a tag page, show all characters as small squares (thinking Mahjong tile approach), all gridded up. That's MVP
- Navigation that allows you to move up and down a tag, explore pagination for top level tags or if things are getting slower than 1 second

### Add DictionaryEntries for HSK vocab that isn't in CEDICT

There's not a lot of this and most is here HSK treats a phrase as singular but CEDICT breaks it out.
For instance "to wear" and "a necktie" both exist in CEDICT, but HSK wants "wear a necktie" together.

This is no great issue, let's just create a custom DictionaryEntry for this, associate our own meaning
and cite ourselves as the source.

See [log/tag_import_errors.log] for the full list.

### User model

Used the `bin/rails generate authentication` to bootstrap a login.

---

## Friday 27 Dec

How far I got:

1. ~~Created the base database models~~
2. ~~Prep to import CC-CEDICT~~
3. ~~Finish processing CC-CEDICT~~
4. ~~Import HSK 2.0 and tag CC-CEDICT~~
5. ~~Import HSK 3.0 and tag CC-CEDICT~~

---

## Sun Dec 8

### 1. Created the base database models

Theory is to have a big pile of "Dictionary Entries" with attached meanings.
These are flexible and should allow for a single canonical import of a UTF-8 Character with multiple meanings attached.
Meanings can also be in multiple languages.

We can also add sources.

### 2. Prep to import CC-CEDICT

Got a tested rake task together to download CC-CEDICT.

### 3. Finish processing CC-CEDICT

This bit I didn't complete, we have to:

- Find or create a source knowing we're importing CC-CEDICT
- Process the file and for each line:
  - Extract the simplified characters (we'll ignore traditional for now)
  - Parse the pinyin into a tone-annotated string
  - Find or create the dictionary entry
  - Parse out the meanings, find or create for each with CC-CEDICT as the source
  - Save the row
- Also implement a progress bar that updates against a count of all non-comment lines vs which line the enumerator is on.

### Tagging up HSK

- Get a list of HSK 2.0 vocab
- Tag all that with "HSK 2.0" tag
- Child tags "HSK 1/2/3/4/5"
- Within those tag up the vocab from each lesson in the standard course
- Demonstrate we can query for "HSK 4 上 - Lesson 1" vocab and get relevant vocab (order doesn't matter)

### End goal

> Given a word list of HSK 4 vocab
> Show me all key vocab sorted by:
>
> - Mature — Well established, well known characters
> - Learning — Characters I've seen but am still not reliably recognising
> - Not started — Characters I've not started yet
> - Struggling — Characters I seem to be forgetting quite a lot
