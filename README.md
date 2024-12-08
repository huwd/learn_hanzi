# README

How far I got:

## 1. Created the base database models

Theory is to have a big pile of "Dictionary Entries" with attached meanings.
These are flexible and should allow for a single canonical import of a UTF-8 Character with multiple meanings attached
Meanings can also be in multiple languages.

We can also add sources.

## 2. Prep to import CC_CEDICT

got a tested rake task together to download CC_CEDICT

===============================

## 3. @TODO Finish processing CC_CEDICT

This bit I didn't complete, we have to:

- Find or create a source knowing we're importing CC_CEDICT
- process the file and for each line:
  - extract the simplified characters (we'll ignore traditional for now)
  - parse the pinyin into a tone annotated string
  - find_or_create the dictionary entry
  - parse out the meanings, find_or_create for each with CC_CEDICT as the source
  - save the row
- Also impliamnet a progress bar that updates against a count of all non comment lines vs which line the enumerator is on.

## Then what

### Tagging up HSK

- Get a list of HSK 2.0 vocab
- Tag all that with "HSK 2.0" tag
- Child tags "HSK 1/2/3/4/5"
- Within those tag up the vocab from each lesson in the standard course
- Demonstrate we can query for "HSK 4 上 - Lesson 1" vocab and get relevant vocab (order doesn't matter)

### API to return Dictionary Entries by tag

- define a path that takes a tag and returns all entries
- return metadata for child tags too

### Frontend

- Show all the top level tags
- Nest children below down to two or three levels of depth
- For a given tag return all characters

#### Make it look good

Come up with a card? unit for each character, allow them to grid nicely

### Authentication

See if we can create a User model and auth them with Rails 8

### Anki

For a given user, import their raw anki backup,
extract their learning profile and match them to dictionary entries

==============

End goal

> Given a word list of HSK 4 vocab
> Show me all key vocab sorted by:
>
> - Mature - Well established, well known characters
> - Learning - Characters I've seen but am still not reliably recognising
> - Not started - Characters I've not started yet
> - Struggling - Characters I seem to be forgetting quite a lot