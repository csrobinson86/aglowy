# Bookmarks

A person saves a jw.org page or a scripture to come back to, and finds their bookmarks in a tab beside their notes. Stories live under the **BOOKMARKS-01** epic, which runs after NOTES-01.

Frames in `docs/design/bookmarks/` (README there). Mockups are in the "Bookmarks" row on the design canvas.

## Decisions (Casey, 16 Nov)

- **A tab in Notes.** Notes gets two tabs, Notes and Bookmarks, sharing collections, tags and search. There's no new sidebar item.
- **Only jw.org and wol.jw.org pages,** the same sites the AI is allowed to search (`docs/design/ai.md`), plus single scriptures.
- **Bookmarks get a collection and tags,** like notes and studies.
- **Not in the first version:** pasting a link to make a bookmark, bookmarks on Home, and bookmark buttons in family studies.

## What a bookmark is

Either a **page** (a jw.org or wol.jw.org link with its title) or a **scripture** (a `Bible::Reference`, which opens on jw.org, or in JW Library if it's installed). Each one has:
- an optional comment of the person's own, up to 280 characters
- one collection, or none
- tags
- where it was saved from (a study or a note), linking back while that still exists

Bookmarks are private, like everything in Mine (`docs/design/app-shell.md`).

## Models

### `Bookmark`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK → users, not null | Personal; follows the person |
| `url` | string | nullable; check `url ~ '^https://(www\.)?(jw\.org\|wol\.jw\.org)/'`; unique with `user_id` | A page |
| `scripture` | string | nullable; check `scripture ~ '^\d+:\d+(:\d+(-\d+)?)?$'`; unique with `user_id` | A scripture: the `Bible::Reference` id ("19:23:4") |
| `title` | string | nullable, up to 120 characters | A page's title, from the search result. Scriptures show the reference instead |
| `comment` | string | nullable, up to 280 characters | |
| `collection_id` | uuid | FK → collections, nullable, `on_delete: :nullify` | Must be `Collection.for_notes` and the person's own (validation) |
| `source_type`, `source_id` | string, uuid | nullable together; check `source_type` in (`PersonalStudy`, `PersonalNote`) | Where it was saved from |

- A check makes exactly one of `url` and `scripture` present: `num_nonnulls(url, scripture) = 1`.
- **`url` is normalized before it's saved,** with `Ai::SourceLink.new(url, allowed_hosts: Bookmark::HOSTS).url` (`jw.org`, `www.jw.org`, `wol.jw.org`): https only, no fragment, no `utm_` parameters. A URL it turns into nil is invalid. The same page bookmarked twice is the same row.
- **`scripture` must parse:** `Bible::Reference.find(scripture)` (validation). `reference` returns it, so views show `reference.to_s` and link `reference.jw_url`.
- `include Taggable`. Add `Bookmark` to the `taggings.taggable_type` check and `taggable_by?`.
- `belongs_to :source, polymorphic: true, optional: true`. `PersonalStudy` and `PersonalNote` each get `has_many :bookmarks, as: :source, dependent: :nullify`, so deleting the study or note keeps its bookmarks.
- At most 2,000 bookmarks per person (validation, like the 200-tag limit).
- Scopes: `pages`, `scriptures`, `recent_first`, and `matching(text)` on title, comment, collection name and tag name, plus the scripture's book: when `Bible::Book.match(text)` finds books, it adds `scripture LIKE '<book number>:%'` for each. Nothing here is encrypted, so search runs in SQL.
- `kind`: `:page` or `:scripture`.

### `User`

- `has_many :bookmarks, dependent: :delete_all`
- `bookmark_for(url: nil, scripture: nil)`: the person's bookmark for a page or scripture, or nil.
- `bookmarked`: one query for the keys of everything the person has bookmarked (normalized URLs and scripture ids), as a `Set`. A page with many bookmark buttons loads it once and passes it to each button, so the buttons cost no query each.
- `bookmark(url: nil, scripture: nil, source:)`: finds or creates the bookmark. For a page, the title comes from the source, never from the form: `source.sources` for a study, matched by normalized URL. A page that isn't in the source's sources is refused, so a bookmark can only hold a link Aglowy showed the person. A scripture must be in the source's `scripture_references`.

### `Collection`

- Collections that are `for_notes` hold bookmarks too. `has_many :bookmarks, dependent: :nullify`.
- **Changing `used_in` away from Notes** is refused while the collection holds notes or bookmarks: "3 bookmarks are in this collection. Move them first." (`docs/design/personal-study.md`, Collection).

### `PersonalStudy#scripture_references`

The references in the study's answered paragraphs, in order and without duplicates, found with `Bible::Linker`'s parsing. It's the list for "Scriptures in this study", and what a scripture bookmark saved from a study is checked against.

## Pages and routes

Under `/:household_id`, so they use the household layout. Bookmarks are always found through `Current.user.bookmarks`, so another person's bookmark is a 404.

| What | Route | Frame |
| --- | --- | --- |
| The Bookmarks tab | `GET /:household_id/bookmarks` (`BookmarksController#index`; `?collection=`, `?tag=`, `?kind=page\|scripture`, `?q=`) | `bookmarks.png`, `bookmarks-dark.png` |
| Save | `POST /:household_id/bookmarks` with `url` or `scripture`, plus `source_type` and `source_id` | `personal-study-bookmarks.png`, `note-bookmarks.png` |
| Edit | `PATCH /:household_id/bookmarks/:id` (title for a page, comment, collection) | `bookmark-edit.png` |
| Remove | `DELETE /:household_id/bookmarks/:id` | |
| Tags | `POST`/`DELETE /:household_id/bookmarks/:bookmark_id/taggings` (`Taggings::BookmarksController`, sharing the `Tagging` concern) | |
| On a phone | the same pages | `phone-bookmarks.png` |

### The tabs

- Notes (`/:household_id/notes`) and Bookmarks (`/:household_id/bookmarks`) share a header: the `h1` "Notes", then a Primer `UnderlineNav` labelled "Notes and bookmarks" with "Notes" and "Bookmarks", each with its count (`Primer::Beta::Counter`). The current tab is `aria-current="page"`.
- "New note" shows only on the Notes tab.
- The sidebar's "Notes" item is selected on both (`selected_by_ids` includes `:bookmarks`).

### The Bookmarks tab

- **Left column:** "Collections" (`for_notes`, with "All bookmarks" first and each count of bookmarks), then "My tags" (the person's tags that are on a bookmark, with counts). Each sets the filter.
- **Main column:**
  - search ("Search titles, comments, collections and tags")
  - a Primer `SegmentedControl` labelled "Show": All, Pages, Scriptures (`?kind=`)
  - the bookmarks, newest first, in a `BorderBox`, one row each:
    - an icon: `link` for a page, `book` for a scripture
    - the title (or the reference) linking out, opening in a new tab, then "jw.org", "wol.jw.org" or "Scripture"
    - the comment
    - tags as Labels, then "Collection · date · from <study or note>", linking to the source while it exists
    - "Edit" and the filled bookmark button (Remove)
  - under the list: "Bookmark a page or scripture with the bookmark button beside it in a personal study or a note. Pages open on jw.org; scriptures open on jw.org, or in JW Library if it's installed."
- **Empty state:** "No bookmarks yet." with the line above as its description. No action button, since bookmarks are made where the links are.
- Paginate at 50, like other long lists.

### Edit a bookmark

A Primer `Dialog` "Edit bookmark" from the row's Edit button (frame `bookmark-edit.png`):
- a muted line: the host (or "Scripture") and "saved from "<source>""
- `Bookmarks::EditForm` (a Primer form class): Title (pages only; required, up to 120), Comment (optional, up to 280, with the caption "Up to 280 characters."), Collection (`for_notes` plus None)
- the tag editor (`TagEditorComponent`) for the bookmark
- footer: "Remove bookmark" (danger) on the left; Cancel and Save on the right

Saving replaces the row with a Turbo Stream and closes the dialog. A refused save shows its errors by the fields, in the dialog.

### The bookmark button

`BookmarkButtonComponent.new(url:, title:, source:, bookmarked:)` or `(scripture:, source:, bookmarked:)`, where `bookmarked` is `Current.user.bookmarked`, renders a Primer `IconButton`:
- `bookmark` with the label "Bookmark: <title>" when it isn't saved; `bookmark-fill` with "Remove bookmark: <title>" when it is, with `aria-pressed`
- tapping it saves or removes (`button_to` with `POST` or `DELETE`), and the response is a Turbo Stream that replaces every button for the same page or scripture on the page, so "Pages used" and "Sources in this study" stay in step
- `dom_id` for the button comes from a digest of the URL or the scripture id, never the raw URL

It appears:
- on a Personal study answer, beside each page in "Pages used"
- on a study, in "Sources in this study", and in a new "Scriptures in this study" box above it (each scripture as a link, with "Each opens on jw.org, or in JW Library if it's installed.")
- on a note, beside each scripture in "Scriptures in this note" (`docs/design/notes.md`)

Only the owner of the study or note sees the buttons. A head reading a child's study under a study AI grant (`docs/design/personal-study.md`, Children) sees no bookmark buttons.

### Elsewhere

- **Tags:** a tag's page (`/:household_id/tags/:name`) gets a "Bookmarks" group (`docs/design/tags.md`).
- **Settings → Tags and collections** (`docs/design/settings.md`, from SETTINGS-01): tag counts include bookmarks, and each collection's count adds "N bookmarks". Until that's built, the My tags page counts them.
- **Deleting a collection** keeps its bookmarks; they leave the folder.

## Traps

- **Never fetch the page.** A page's title comes from the AI's search result, stored on the study's sources. Nothing in Aglowy requests jw.org (`docs/design/ai.md`, Traps).
- **Never trust a title or URL from the form.** The title comes from the source record. The URL must be one of that source's sources, normalized by `Ai::SourceLink`.
- **Look up the source through `Current.user`** (`Current.user.personal_studies`, `Current.user.personal_notes`), so another person's study is a 404.
- **Escape titles and comments.** A title came from a search result: treat it as untrusted text, like any AI output.
- **Links open in a new tab with `rel="noopener"`**, like other links to jw.org.
- **A bookmark outlives its source.** Show "from <source>" only while the source exists.
- **Tags stay private** (`tags_for(Current.user)`).

## States each story checks

- Owner, another member (404), a non-member (404); a head reading a child's study (no buttons)
- A page and a scripture; saved and not saved; the same page in two places on one page
- A URL on another host, with a fragment or `utm_` parameters, or not in the source's sources
- No bookmarks; bookmarks in a collection, in none, with tags, with and without a comment; the source deleted
- Filters: collection, tag, kind, search
- Desktop and phone; light and dark
