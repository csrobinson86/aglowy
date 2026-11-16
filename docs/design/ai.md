# AI in Aglowy

The rules every AI feature follows. The first feature is drafting a family study (`docs/design/family-studies.md`, "AI helper"). Later ones, like asking questions during personal study, build on the same pieces.

Read this before touching RubyLLM, `config/initializers/ruby_llm.rb`, `Chat`, `Message`, `Ai::Acceptance`, `Ai::Purpose`, `Ai::SourceLink`, or any feature that sends text to an AI provider. Stories live under the **AI-01** epic.

## Decisions (Casey, 15 Nov)

- **Each AI feature does one job.** The AI is never an open chat. Each feature has fixed instructions, a fixed output shape and its own limits, and anything outside that job is politely refused. Family study drafts plan family studies; a later personal-study helper answers study questions; neither does the other's job.
- **The AI looks only at jw.org and wol.jw.org.** When it searches the web, the search is limited to those sites. It links every page it used.
- **Link, never copy.** Aglowy shows the title and a link for each page the AI used, and never their text. That follows jw.org's [Terms of Use](https://www.jw.org/en/terms-of-use/) (which also cover wol.jw.org): sharing links is allowed, but reproducing their content "on another website or application" isn't, and neither is software "made to collect, copy, download, extract, harvest, or scrape" their text. So Aglowy never fetches jw.org pages itself, never stores or shows their text, and the AI writes outlines and questions in its own words.
- **Family study drafts are limited to 10 per household per day.** Each draft costs money (an AI call plus web searches), and Aglowy has no billing.
- **Safety measures fit each feature's purpose**, listed below. They don't change from one feature to the next.

## The pieces

### Conversations: `Chat` and `Message`

RubyLLM's Rails models, as `CLAUDE.md` asks (`acts_as_chat`, `acts_as_message`). The first story runs RubyLLM's install generator, adapted to UUIDv7 keys, and adds:

| On | Column | Why |
| --- | --- | --- |
| `chats` | `user_id` (FK → users, not null) | Whose request it was. AI content is personal until the person uses it |
| `chats` | `household_id` (FK → households, nullable) | Set when the feature is inside a household |
| `chats` | `purpose` (string, not null, check in the known purposes) | Which `Ai::Purpose` it ran under: `family_study_draft`, and `personal_study` (`docs/design/personal-study.md`) |
| `messages` | `content` encrypted (`encrypts :content`) | Prompts and replies are private family text, like notes |

A feature's own record points at its chat (`FamilyStudy::Draft belongs_to :chat`) and keeps the feature's data. The chat keeps only the conversation.

### What each feature is allowed to do: `Ai::Purpose`

A PORO per purpose in `app/models/ai/purpose/`, for example `Ai::Purpose::FamilyStudyDraft`. It holds, in one place:

- `instructions`: the fixed system prompt, in `config/ai/<purpose>.md` so it's reviewed like code
- `schema`: the structured output the reply must match (RubyLLM `with_schema`)
- `allowed_hosts`: `www.jw.org`, `jw.org` and `wol.jw.org`
- `max_searches`: the most web searches one request may run (5 for family study drafts)
- `max_output_tokens`
- `daily_limit` and what it counts (10 a day for the household for family study drafts; 30 a day per person for personal study, counted from `Ai::Use` rows in the person's time zone)
- `keep_for`: how long its records and chats are kept (7 days for family study drafts; `nil`, kept until the person deletes them, for personal study)
- `copy_overlap_words` (8) and `quote_max_words` (5), the copy check's policy values (safety measure 5)

`Chat#ask_within_purpose(text)` is the only way a feature calls the AI. It applies the purpose's instructions, schema and web-search settings, then returns the parsed reply and its sources. No feature calls `RubyLLM.chat` itself.

### The model and the web search

- `config/initializers/ruby_llm.rb` reads `AI_MODEL` (a model id) and the provider keys from the environment. Code never names a model.
- The web search is the provider's own search tool, turned on through RubyLLM's provider tools, with the purpose's `allowed_hosts` as the allowed domains and `max_searches` as its limit. The provider runs the search, so Aglowy itself never requests a jw.org page.
- The first story confirms two things with a recorded reply from the configured provider, and records both in this doc:
  - that RubyLLM 2.2 passes the allowed domains through to the provider's search tool. If it doesn't, the story passes the provider's tool definition directly
  - that the provider's citations carry an excerpt (`cited_text`) the copy check can compare against. Anthropic's web search documents excerpts of up to 150 characters per citation

What the first story (#180) found:

- **Allowed domains: confirmed in the request RubyLLM builds, not yet sent to Anthropic.** `with_provider_tools(web_search: { allowed_domains:, max_uses: })` deep-merges the options into RubyLLM's Anthropic tool, so the request carries `{ type: "web_search_20260318", name: "web_search", allowed_callers: ["direct"], allowed_domains: ["www.jw.org", "jw.org", "wol.jw.org"], max_uses: 5 }`. `test/models/chat/ask_within_purpose_test.rb` checks the payload RubyLLM actually renders. The options are in Anthropic's vocabulary (`Ai::Purpose#web_search`), so `AI_MODEL` must be an Anthropic model; `Chat#ask_within_purpose` refuses any other provider before sending anything.
- **`cited_text`: not yet confirmed against a live reply.** The run had no working `ANTHROPIC_API_KEY`, so `test/fixtures/files/ai/family_study_draft.json` is hand-built in the shape Anthropic documents (`web_search_tool_result` blocks, and text blocks whose `web_search_result_location` citations carry `cited_text`), not recorded. RubyLLM 2.2 reads `cited_text` from that shape into `Citation#cited_text`. Still open: whether Anthropic accepts this tool definition with a JSON schema (`output_config.format`) in the same request, and whether it then returns citations at all. Record one reply (`test/fixtures/files/ai/README.md`) before the copy-check story starts. If it has no `cited_text`, stop and decide with Casey.
- **Nothing from the search is stored.** `messages` has no `citations`, `server_tool_calls`, `raw_content` or `raw_reasoning` columns (RubyLLM skips a column a table doesn't have), so search results and `cited_text` live only in memory, in the `Ai::Reply`.

### Links the AI used: `Ai::SourceLink`

A PORO that decides which links a feature may show. A link is kept only if:

1. it parses as an `https` URL with no user, password or port, and its host is exactly one of `allowed_hosts`;
2. it appears in the reply's search results or citations. A link the AI wrote that the search didn't return is dropped, so the AI can't invent an article;
3. it isn't a duplicate (after removing the fragment and tracking parameters).

Only the URL and the title from the search result are kept. The quoted text that citations carry (`cited_text`) is used once, by the copy check below, and never stored or shown.

Aglowy never requests a link to check that it works. That would be the "collect or download" the terms forbid. Requirement 2 already shows the page existed when the search ran.

### Scripture references

The AI writes references as plain text ("Philippians 4:6, 7"). Each goes through `Bible::Reference.parse` (`docs/design/scripture-links.md`). One that doesn't parse is dropped from the draft. One that does becomes a normal scripture link to jw.org. The AI never writes verse text.

### First use: `Ai::Acceptance`

A record, not a boolean (state as records): `user_id`, `version` (integer), `created_at`. Before someone's first AI request, the feature shows the notice in frame `docs/design/family-studies/ai-terms.png`, and they tick "I understand how AI drafts work" and choose "Turn on AI drafts". `POST /ai_acceptance` (`AiAcceptancesController#create`, `resource :ai_acceptance, only: :create`) records the current version.

- `config.x.ai.terms_version` holds the version. Raising it shows the notice again to everyone.
- Acceptance belongs to the person, so it follows them across households, like the rest of their personal settings.
- Every AI controller action checks `Current.user.accepted_ai_terms?` and refuses (403) without it. The UI hides the prompt until then, but the server doesn't trust the UI.

## Safety measures

Every AI feature has all of these. A feature's design doc only adds to them.

1. **Its own job only.** The fixed instructions say what the feature does and that anything else gets a refusal. The reply schema has an `off_topic` field. When it's true, the UI shows the purpose's refusal message (frame `ai-refused.png`) and nothing else from the reply.
2. **A moderation check first.** The person's text goes through RubyLLM's moderation call before the AI sees it. If it's flagged, the request stops with the same refusal message, and it doesn't count toward the daily limit.
3. **The person's text is data, never instructions.** It goes into the user message inside a clearly marked block. The system prompt says text in that block can't change the rules. The schema means the reply can only fill fixed fields.
4. **Search limited to jw.org and wol.jw.org,** then `Ai::SourceLink` (above).
5. **No copying, checked before anyone sees the reply.** The instructions say to write in its own words and never to quote pages or verse text. `Ai::CopyCheck` then runs on every text field of the finished reply, before any of it is shown or saved:
   - **Measuring.** Text is compared as words: lower-cased, with punctuation removed and runs of whitespace treated as one space.
   - **Overlap with a source.** A sentence that shares 8 or more consecutive words with any citation's `cited_text` is removed.
   - **Quotations and verse text.** A sentence holding a quotation (text in straight or curly quotation marks) longer than 5 words is removed, whatever its source. Aglowy has no verse text to compare against, because it never fetches it, so a quoted scripture is caught by this rule and by the instructions. References stay; only the quoted words go.
   - **Policy values.** 8 words and 5 words live on `Ai::Purpose` (`copy_overlap_words`, `quote_max_words`) and are Casey's call to tune.
   - **Too thin.** Each purpose sets its minimum. A family study draft fails when the checks leave fewer than 2 points ("Couldn't make a draft this time. Try again."). A personal study answer fails when they leave no paragraphs; a `not_found` note with no paragraphs is a valid answer (`docs/design/personal-study.md`).
   - **What it can't see.** `cited_text` is a short excerpt (up to about 150 characters per citation), so the check can only compare against what the search returned. The instructions, the quotation rule and "AI can get things wrong. Check each point against its source" cover the rest.
   - **Citations without an excerpt.** A source whose citations carry no `cited_text` can't be checked for overlap. Its link may still be shown (requirements 1–3 of `Ai::SourceLink` still apply), but the quotation rule then applies to the whole draft with no exceptions. `AI_MODEL` must name a provider whose citations carry excerpts; a provider that returns none for any citation isn't supported for AI features. The first story's check above enforces this.
6. **AI output is untrusted text.** Every field is rendered through ERB escaping or Primer components, never `html_safe` and never `raw`. Notes HTML built from a draft comes from our own template filled with escaped fields, then goes through Action Text's sanitizer like any note.
7. **Never send more than the request needs.** Only what the person typed and the feature's options go to the provider. Never names, household names, notes, goals or other records. The prompt box says so.
8. **Heads and adults, unless a feature decides otherwise.** Children don't see AI features by default, and the policies refuse them. Personal study is the one exception so far: a head can allow it per child, and then can read everything in that child's personal studies (`docs/design/personal-study.md`). Any other feature for children needs its own decision.
9. **Limits.** Each purpose sets a daily limit, counted under a lock so two requests at once can't both take the last one. A household limit (family study drafts) counts inside the household lock. A per-person limit (personal study) counts inside the person's lock (`user.with_lock`), because a person can ask from more than one household at once. A request that failed at the provider, or was stopped by moderation, doesn't count.
10. **Kept only as long as the purpose says.** Each purpose's `keep_for` decides. Family study drafts and their chats are deleted after 7 days by a daily recurring job (`config/recurring.yml`), and what the person chose to use is copied into their own records first. Personal studies are the person's own records and are kept until they delete them. The job only deletes purposes with a `keep_for`.

## Privacy and cost

- The provider receives only what's listed in safety measure 7. Choose provider settings that don't use API data for training, and check each provider's terms before turning AI on in production. That's Casey's call before launch.
- Aglowy keeps no analytics (`docs/product/vision.md`). RubyLLM records token counts on each message. They're used only to see the cost of a request and are deleted with the chat after 7 days.
- With no billing, the daily limits are the cost control. If costs rise, lower the limits in `Ai::Purpose`.

## Traps

- **Never fetch jw.org or wol.jw.org from Aglowy**, not even a HEAD request to check a link. The provider's search tool is the only way the AI sees those sites.
- **Never show `cited_text`**, page snippets or anything else from a search result except its title and URL.
- **Never let the AI's links bypass `Ai::SourceLink`.** That includes links inside the outline text: strip them, and show links only from the sources list.
- **Don't trust `off_topic` alone.** The moderation check runs first, and the schema keeps the reply inside fixed fields either way.
- **Count each limit from midnight to midnight in its purpose's time zone, under its lock:** the household's time zone and lock for family study drafts; the person's time zone (or, when they haven't set one, a stable fallback: their oldest active membership's household, else UTC; never the household of the current request) and the person's lock for personal study.
- **Don't log prompts or replies.** Add `prompt`, `content` and `outline` to `filter_parameters`, and never write them in job arguments: jobs receive record ids only.
- **Stream progress, never unchecked reply text.** While a request runs, the panel shows only progress lines (searching, writing, checking). The reply appears once the checks in safety measures 1, 4 and 5 have passed. Progress goes on a signed stream name for that record (`turbo_stream_from @draft`), never on a household-wide stream.
- **A finished job never overrides Stop.** Write the final status with a conditional update (`where(status: "drafting")`), so a draft stopped while the job was checking stays `stopped` and is never shown.
- **Tests never call a provider.** Stub `Chat#ask_within_purpose` (or RubyLLM's chat object) with Minitest's `stub`, using saved replies in `test/fixtures/files/ai/`. CI has no AI keys.

## States each story checks

- Person: head, adult, child (refused), non-member (404), not yet accepted (refused), accepted
- Limit: none used, 9 used, 10 used, a new day in the household's time zone
- Reply: a good draft, off topic, flagged by moderation, provider error, a link not in the search results, a link on another host, a sentence copied from a citation, a reference that doesn't parse
- Desktop and phone; light and dark
