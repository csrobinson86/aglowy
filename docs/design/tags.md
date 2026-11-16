# Tags

Each person can tag their own meeting notes, personal goals, personal studies and notes, then find everything with a tag in one place. Stories live under the **TAGS-01** epic.

Frames in `docs/design/personal-study/`: tags on the list of studies (`personal-studies.png`), adding a tag (`personal-study.png`, under the title) and a tag's page (`personal-study-tag.png`).

## Decisions (Casey, 16 Nov)

- **Tags belong to the person.** Nobody else sees them, even on a meeting note or goal they've shared with the household.
- **Four kinds of thing can be tagged:** the person's meeting notes, their personal goals (not family goals), their personal studies (`docs/design/personal-study.md`) and their notes (`docs/design/notes.md`, added by NOTES-01).
- **Tags and collections both exist.** Collections are folders for personal studies and notes (`Collection` in `docs/design/personal-study.md`); tags work across all four kinds. They don't replace each other.

## Models

### `Tag`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK → users, not null | Whose tag |
| `name` | string | not null, check `name ~ '^[a-z0-9][a-z0-9-]{0,29}$'`, unique with `user_id` | Shown as `#name` |

- `Tag.normalize(text)`: strips a leading `#`, downcases, turns spaces and underscores into hyphens, drops other characters, and trims to 30. "Talk Prep" and "#talk_prep" both become `talk-prep`.
- `user.tags.find_or_create_by_name!(text)` normalizes, then finds or creates the tag. A name that normalizes to nothing is invalid.
- At most 200 tags per person (validation). Plenty for organizing, and it stops runaway lists.

### `Tagging`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `tag_id` | uuid | FK → tags, not null, `on_delete: :cascade` | |
| `taggable_type` | string | not null, check in (`MeetingNote`, `Goal`, `PersonalStudy`, `PersonalNote`) | |
| `taggable_id` | uuid | not null, unique with `tag_id` and `taggable_type` | |

- The tag's person must own the tagged thing: `MeetingNote#user`, `Goal#user` (a personal goal, so `household_id` is null), `PersonalStudy#user` or `PersonalNote#user`. This is a validation; the database can't check across a polymorphic link.
- At most 10 tags on one thing (validation).

### `Taggable` concern

Included in `MeetingNote`, `Goal`, `PersonalStudy` and `PersonalNote` (the last added by NOTES-01).

- `has_many :taggings, as: :taggable, dependent: :delete_all` and `has_many :tags, through: :taggings`
- `tag_with(text, by: user)` finds or creates the person's tag and adds it; `untag(tag)` removes it
- `taggable_by?(user)`: true when `user` owns it. For `Goal`, only personal goals
- `scope :tagged_with, ->(tag) { joins(:taggings).where(taggings: { tag_id: tag.id }) }`
- `tags_for(user, membership: Current.membership)`: the tags to show. Views call this, never `tags` directly.
  - `MeetingNote`, `Goal` and `PersonalNote`: all of them for the owner, none for anyone else.
  - `PersonalStudy`: the same, plus all of them when `ChildStudyPolicy.new(membership, study).show?` is true, which means a head of that household reading a child's study under a study AI grant (`docs/design/personal-study.md`, Children). It never extends to the child's meeting notes or goals.

## Pages and routes

| What | Route | Notes |
| --- | --- | --- |
| Add a tag | `POST /:household_id/meeting_notes/:meeting_note_id/taggings`, and the same under `goals`, `personal_studies` and `notes` (`Taggings::…Controller`, one per parent, sharing a `Tagging` controller concern) | Body: `name`. The parent is found through `Current.user`, so someone else's note is a 404. Responds with a Turbo Stream that replaces the tag editor |
| Remove a tag | `DELETE …/taggings/:id` | The same lookup |
| My tags | Settings → Tags and collections (`docs/design/settings.md`); was `GET /:household_id/tags` until SETTINGS-01, when `household_tags_path` is removed and its callers use `household_settings_tags_path` | Each tag with how many things carry it. Rename and delete here |
| A tag | `GET /:household_id/tags/:name` (`TagsController#show`) | Everything the person tagged with it, grouped as Meeting notes, Personal studies, Notes and My goals (frame `personal-study-tag.png`). No sidebar item is selected |
| Rename | `PATCH /:household_id/tags/:name` | Renaming to a name the person already has fails with "You already have #name." No merging |
| Delete | `DELETE /:household_id/tags/:name` | Removes the tag from everything. Asks first with a Primer dialog |

Tag pages sit under `/:household_id` only so they use the household layout. The data is the person's, found through `Current.user.tags`, so they look the same from any household.

### The tag editor

`TagEditorComponent` sits under a title on a meeting note, a personal goal and a personal study, and in the controls of a note (`docs/design/notes.md`), for the owner only. Adding and removing work the same everywhere:
- each tag as a Primer `Label` linking to its page, with a remove button labelled "Remove tag <name>"
- an "Add a tag" input built on Primer's `AutoComplete`, suggesting the person's own tags with their counts, plus "Create "#<name>"" when the text is new
- Enter adds, Escape closes the suggestions, and focus returns to the input after adding

### Filtering lists

The meeting notes list, My goals, Personal study and Notes each take `?tag=<name>`. When it's set, the page shows a removable "#name" filter and only tagged things. Each list row shows its tags as small Labels.

## Privacy

- **Tags never appear on shared views.** A shared meeting note read by the household, a shared personal goal, and Home's household cards render no tags. Views call `tags_for(Current.user)`, which is empty for anyone but the owner.
- **One exception, decided with personal study.** A head who has turned on AI personal study for a child can read that child's personal studies, including their tags (`docs/design/personal-study.md`, Children). It doesn't extend to the child's meeting notes or goals.
- Leaving a household changes nothing: tags belong to the person, like the things they tag.

## Traps

- **Never render `record.tags`** in a view. Use `tags_for(Current.user)`, so a shared view can't leak them.
- **Never trust a tag id from the form for another person's tag.** Look tags up through `Current.user.tags`.
- **Don't let the autocomplete list anyone else's tags.** Its source is `Current.user.tags` only.
- **Normalize before uniqueness.** "Ministry" and "#ministry" are the same tag.
- **Family goals can't be tagged.** `taggable_by?` is false for them, and the route returns 404.

## States each story checks

- Owner, another household member viewing a shared note or goal, a non-member (404)
- No tags, one, 10 (the limit), a new name, an existing name typed differently ("Ministry"), a name that normalizes to nothing ("###")
- A tag on all three kinds, and the tag page grouping them
- Rename to a free name and to a taken one; delete
- Desktop and phone; light and dark
