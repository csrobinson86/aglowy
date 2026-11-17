module CollectionsHelper
  USED_IN = { "both" => "Used in Notes and Personal study", "studies" => "Used in Personal study only", "notes" => "Used in Notes only" }.freeze

  # "· 6 notes, 4 studies", leaving out what it has none of (frame settings-tags.png). Needs with_contents_counts.
  def collection_contents(collection)
    counts = { "note" => collection.personal_notes_count, "study" => collection.personal_studies_count }.select { |_, count| count.positive? }
    "· #{counts.any? ? counts.map { |word, count| pluralize(count, word) }.join(", ") : "Empty"}"
  end

  def collection_used_in(collection)
    USED_IN.fetch(collection.used_in_in_database)
  end
end
