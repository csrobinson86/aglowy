# Hannah has turned on AI features and her study guide, so Settings → You → Study guide shows it ticked
# (docs/design/study-guide.md, The Settings section; frame phone-guide-settings.png). Sam hasn't accepted the AI terms,
# so his shows the disabled box and the line saying where to accept them. Turning it on again keeps the one row.
hannah = seeded_person("head@example.com")
seeded!(hannah.accept_ai_terms(understood: "1"))
hannah.turn_on_study_guide || raise("Hannah's study guide wasn't turned on")
