# Data Gaps

## HSK 3.0 unresolved dictionary gaps

After importing:

- CC-CEDICT
- HSK 3.0 word lists from `krmanik/HSK-3.0`
- TSV-based HSK stub entries
- curated `db/custom_dictionary_entries.yml`

there are still 49 HSK words that cannot be tagged because they are absent
from both CC-CEDICT and the krmanik TSV fallback data.

### Counts

| Level | Expected | Covered | Missing |
|---|---:|---:|---:|
| HSK 1 | 500 | 497 | 3 |
| HSK 2 | 771 | 764 | 7 |
| HSK 3 | 973 | 966 | 7 |
| HSK 4 | 1,000 | 995 | 5 |
| HSK 5 | 1,071 | 1,067 | 4 |
| HSK 6 | 1,140 | 1,134 | 6 |
| HSK 7-9 | 5,636 | 5,619 | 17 |
| **Total** | **10,091** | **10,042** | **49** |

### Why this remains

These words exist in the TXT lesson lists, but have no matching row in the TSV
files used for fallback stub creation. Without at least pinyin and a gloss,
the importer has no source data to safely create entries.

### How to audit current gaps

Run:

```bash
bin/rails tag_import:audit_hsk_3_gaps
```

This reports per-level coverage and lists words still missing from both the
dictionary and TSV fallback files.

### Resolution options

1. Accept this documented gap.
2. Add a third dictionary source that covers the missing words.
3. Manually curate entries in `db/custom_dictionary_entries.yml`.
