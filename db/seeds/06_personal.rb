# Hannah's tags, collections, personal studies, notes and bookmarks, and Lucia's own study. Answers are stored as the answer job
# writes them, in sample text written here, so no AI is asked and no one's daily questions are used. Their sources
# are jw.org and wol.jw.org addresses with placeholder titles; nothing fetches them.
head, lucia = seeded_person("head@example.com"), seeded_person("lucia.rivera")

collections = { "Bible characters" => "both", "Convention 2026" => "both", "Research" => "studies", "Quick thoughts" => "notes" }
  .to_h { |name, used_in| [ name, head.collections.find_by(name: name) || seeded!(head.collections.add(name: name, used_in: used_in)) ] }

def seed_answer(paragraphs, next_questions: [])
  { "not_found" => false, "not_found_note" => "", "paragraphs" => paragraphs, "next_questions" => next_questions }
end

def seed_source(path, title)
  { "url" => "https://#{path}", "title" => "[Sample article] #{title}" }
end

def seed_personal_study(user, title:, collection: nil, tags: [], questions: [])
  user.personal_studies.find_by(title: title) || user.personal_studies.new(title: title, collection: collection).tap do |study|
    study.save!
    tags.each { study.tag_with(it, by: user) }
    questions.each { study.questions.create!(user: user, **it) }
  end
end

daniel = seed_personal_study(head, title: "Daniel's courage", collection: collections["Bible characters"], tags: %w[ faith courage ],
  questions: [
    { prompt: "Why did Daniel keep praying when it was against the law?", status: "answered",
      answer: seed_answer([ "Sample answer: Daniel put his worship of Jehovah first, as Daniel 6:10 describes.",
                            "Sample answer: his habit of prayer had been built over many years." ],
                          next_questions: [ "How can I build a habit of prayer?" ]),
      sources: [ seed_source("www.jw.org/en/library/bible/", "Daniel in the lions' den"),
                 seed_source("wol.jw.org/en/wol/h/r1/lp-e", "Courage in hard times") ] },
    { prompt: "How did Jehovah protect Daniel?", status: "answered",
      answer: seed_answer([ "Sample answer: Daniel 6:22 says an angel shut the lions' mouths." ]),
      sources: [ seed_source("www.jw.org/en/library/bible/", "Daniel in the lions' den") ] }
  ])

seed_personal_study(head, title: "Preparing my heart for the convention", collection: collections["Convention 2026"], tags: %w[ prayer ],
  questions: [
    { prompt: "How can I get more from a convention?", status: "answered",
      answer: seed_answer([ "Sample answer: prepare beforehand, take notes, and talk about it as a family afterwards." ]),
      sources: [ seed_source("www.jw.org/en/", "Getting the most from a convention") ] },
    { prompt: "What's the best phone to buy?", status: "off_topic" }
  ])

seed_personal_study(head, title: "Why does God allow suffering?", collection: collections["Research"], tags: %w[ hope faith ],
  questions: [
    { prompt: "Why does God allow suffering?", status: "answered",
      answer: seed_answer([ "Sample answer: James 1:13 says God never tries anyone with bad things." ]),
      sources: [ seed_source("www.jw.org/en/bible-teachings/", "Why does God allow suffering?") ] }
  ])

# Daniel's pages bookmarked, as the study's bookmark buttons save them, so Notes' Bookmarks tab has rows
# (docs/design/bookmarks.md). Saving again finds each one.
daniel.sources.each { seeded!(head.bookmark(url: it["url"], source: daniel)) }

seed_personal_study(lucia, title: "Brave like Daniel")

# Every color at least once, two pinned, references in the bodies. The eleventh is Daniel's study note, from a saved answer below.
[
  { title: "Thoughts on Romans 12", color: "yellow", pin: true, collection: "Bible characters", tags: %w[ faith ],
    body: "<p>Rom 12:11: aglow with the spirit. Keep the routine going even on tired days.</p>" },
  { title: "Ministry openings", color: "green", pin: true, collection: "Quick thoughts", tags: %w[ ministry ],
    body: "<p>Ask about hope for the future, then read Rev 21:4.</p>" },
  { title: "Prayer list", color: "blue", tags: %w[ prayer ], body: "<p>Phil 4:6, 7. Grandma's health, the convention, Charlie's school.</p>" },
  { title: "Family worship ideas", color: "purple", tags: %w[ family ], body: "<p>Act out 1 Sam 17 with the children.</p>" },
  { title: "Questions to ask at the meeting", color: "pink", body: "<p>What does Matt 5:3 mean by conscious of spiritual need?</p>" },
  { title: "Convention reminders", color: "orange", collection: "Convention 2026", body: "<p>Pack the badge cards. Read Ps 122:1 the night before.</p>" },
  { title: "Hope in hard times", color: "yellow", tags: %w[ hope courage ], body: "<p>Isa 41:10 again. And Josh 1:9.</p>" },
  { title: "Love in action", color: "red", tags: %w[ family ], body: "<p>1 Cor 13:4-7. Patient first, then kind.</p>" },
  { title: "Bible characters to read about", color: "brown", collection: "Bible characters",
    body: "<p>Ruth 1:16, then Esther 4:14.</p>" },
  { title: "Things to look up later", color: "gray", collection: "Quick thoughts", body: "<p>Who wrote Ps 90? See Ps 90:1.</p>" }
].each do |attributes|
  next if head.personal_notes.exists?(title: attributes[:title])

  note = head.personal_notes.new(title: attributes[:title], color: attributes[:color], body: attributes[:body],
                                 collection: collections[attributes[:collection]])
  note.link_scriptures
  note.save!
  attributes[:tags].to_a.each { note.tag_with(it, by: head) }
  note.pin_to_top if attributes[:pin]
end

# Daniel's first answer saved to the study's note, as Save to note does. Saving it again changes nothing.
daniel.questions.answered.first.save_to_note

# A scripture from Daniel's answers and one from a note, bookmarked as their buttons save them, so the Bookmarks tab
# has scripture rows and Show has something to narrow (docs/design/bookmarks.md). Saving again finds each one.
seeded!(head.bookmark(scripture: daniel.scripture_references.first.id, source: daniel))
openings = head.personal_notes.find_by!(title: "Ministry openings")
seeded!(head.bookmark(scripture: openings.scripture_references.first.id, source: openings))

# Comments, collections and tags on some of them, as the Edit dialog saves them, so the Bookmarks tab's Collections and
# My tags have counts and search has comments to find. Updating and tagging again changes nothing.
first_page, second_page = daniel.sources.map { head.bookmark(url: it["url"], source: daniel) }
first_page.update!(comment: "Good for return visits.", collection: collections["Bible characters"])
first_page.tag_with("courage", by: head)
second_page.update!(collection: collections["Quick thoughts"])
openings_scripture = head.bookmarks.find_by!(source: openings)
openings_scripture.update!(comment: "Start here when someone is grieving.")
openings_scripture.tag_with("hope", by: head)
