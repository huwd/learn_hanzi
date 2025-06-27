# README

## Up next

### 27th June

Of course I've lost the thread of what I was doing here.

So here's where I see outstanding issues.
Core issue is that having imported my Anki Collection it's managed to import some but not all of my learnings, Charcters I know I've mastered are not showing up as learned.

This is the big barrier to progress.

I think the next step is to work out what an appropriately represenative test databsae is, ideally containing a range of characters that I know import well, and also ones that fail.

It should be extensible so I can add future bugs to it. This is likely the core work as it's difficult to track the bug down without further tests.

Additionally we have a few other issues:

#### log/dictionary_import_errors.log

This seems to show CEDICT items we've been unable to import.
I suspect this is either genuine duplicates in CEDICT (surely not?), or something about the ways characters repeat in the language. However I'd understood that constraining uniqueness by meaning would sort it... :thinking:

#### log/tag_import_errors.log

these seem to be legitimate errors, ones where CEDICT doesn't have an entry for them, either because they're a turn of phrase or a combination that doesn't appear. These need custom dictionary entries.

They should represent entries from HSK that don't appear in source CEDICT.

Can draw these from HSK materials perhaps?


#### log/anki_migration.log

Similarly these would represent:

Anki flashcards with phrases that aren't in CEDICT and need a custom entry.

### Anki

Let's do something really grim,
We can dump an anki DB that's basically just sqlite lets try:

```ruby
class AnkiBase < ActiveRecord::Base
  self.abstract_class = true

  establish_connection(
    adapter: 'sqlite3',
    database: '/path/to/your/anki_database.sqlite'
  )

  def readonly?
    true
  end
end
```

then creating models:

```ruby
class Card < AnkiBase
  self.table_name = 'cards' # Replace with the actual table name
end

class Note < AnkiBase
  self.table_name = 'notes' # Replace with the actual table name
end
```

We'll want to replace this before anyone else uses this, but it'll give us access to the learning progress from a DB I should just be able to import and nuke old copies of.

That's out MVP for getting learning progress data.

Then write an association our side that (on import), joins a card to dictionary entries.

Now I should be able to query a value for each piece of vocab in a tag regarding learning.

Initial aim is to do something like, a 1-10 strength score. Then do a green gradient for like... 3-10 and something more alarming for 1 and 2. Then grey out unstarted. Or whatever gets me:

> - Mature - Well established, well known characters
> - Learning - Characters I've seen but am still not reliably recognising
> - Not started - Characters I've not started yet
> - Struggling - Characters I seem to be forgetting quite a lot

Now we'll be getting somewhere on my user need of:
> Show me my progress against HSK learning

## Wednesday Jan 1st

### Frontend

Now is a good time to start,
Let's build it around the tags. Theory is:

- For a tag page, show all characters as small squares (thinking Majong tile approach), all gridded up. That's MVP
- Navigation that allows you to move up and down a tag, explore pagination for top level tags or if things are getting slower than 1 second

### Add DictionaryEntries for HSK vocab that isn't in CEDICT

There's not a lot of this and most is here HSK treats a phrase as singular but CEDICT breaks it out.
For instance "to wear" and "a necktie" both exist in CEDCIT, but HSK wants "wear a necktie" together.

This is no great issue, let's just create a custom DictionaryEntry for this, associate our own meaning
and cite outselves as the source.

See [log/tag_import_errors.log] for the full list.

### User model

used the `bin/rails generate authentication` to bootstrap a login

## Friday 27 Dec

How far I got:

1. ~Created the base database models~
2. ~Prep to import CC_CEDICT~
3. ~Finish processing CC_CEDICT~
4. ~Import HSK 2.0 and tag CC_CEDICT~
5. ~Import HSK 3.0 and tag CC_CEDICT~

## Sun Dec 8

How far I got:

### 1. Created the base database models

Theory is to have a big pile of "Dictionary Entries" with attached meanings.
These are flexible and should allow for a single canonical import of a UTF-8 Character with multiple meanings attached
Meanings can also be in multiple languages.

We can also add sources.

### 2. Prep to import CC_CEDICT

got a tested rake task together to download CC_CEDICT

===============================

### 3. @TODO Finish processing CC_CEDICT

This bit I didn't complete, we have to:

- Find or create a source knowing we're importing CC_CEDICT
- process the file and for each line:
  - extract the simplified characters (we'll ignore traditional for now)
  - parse the pinyin into a tone annotated string
  - find_or_create the dictionary entry
  - parse out the meanings, find_or_create for each with CC_CEDICT as the source
  - save the row
- Also impliamnet a progress bar that updates against a count of all non comment lines vs which line the enumerator is on.

###  Then what

### # Tagging up HSK

- Get a list of HSK 2.0 vocab
- Tag all that with "HSK 2.0" tag
- Child tags "HSK 1/2/3/4/5"
- Within those tag up the vocab from each lesson in the standard course
- Demonstrate we can query for "HSK 4 上 - Lesson 1" vocab and get relevant vocab (order doesn't matter)

### # API to return Dictionary Entries by tag

- define a path that takes a tag and returns all entries
- return metadata for child tags too

### # Frontend

- Show all the top level tags
- Nest children below down to two or three levels of depth
- For a given tag return all characters

### ###  Make it look good

Come up with a card? unit for each character, allow them to grid nicely

### # Authentication

See if we can create a User model and auth them with Rails 8

### # Anki

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