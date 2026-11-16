# Removes, before anyone sees a reply, every sentence that copies a page (docs/design/ai.md, safety measure 5): one
# sharing overlap_words or more words in a row with a citation's excerpt, and one holding a quotation longer than
# quote_max_words. Words are compared lower-cased, without punctuation, whatever the spacing.
class Ai::CopyCheck
  # A sentence runs to its stop (and any closing quotation mark or bracket), or to the end of the text.
  SENTENCE = /\S.*?(?:[.!?]+["”'’)\]]*(?=\s|\z)|\z)/m
  # In double quotation marks, where one left open runs to the end of the text; or in single ones, which only open
  # and close outside a word, so the apostrophe in "don’t" or "let's" is neither, nor the one shortening a year ('90s).
  QUOTATION = /["“][^"”]*(?:["”]|\z)|(?<![[:alnum:]])['‘](?![[:digit:]]{2}s?(?![[:alnum:]]))(?=\S).*?(?<=\S)['’](?![[:alnum:]])/m

  # [fields, removed]: the fields (nested hashes and arrays) with those sentences gone from every string, and
  # whether any were. citations are hashes whose cited_text is an excerpt or a list of them, as Ai::Reply#sources.
  def self.clean(fields, citations:, overlap_words:, quote_max_words:)
    new(citations:, overlap_words:, quote_max_words:).clean(fields)
  end

  def initialize(citations:, overlap_words:, quote_max_words:)
    @overlap_words, @quote_max_words = overlap_words, quote_max_words
    @copied = citations.flat_map { Array(it[:cited_text]) }.flat_map { words(it).each_cons(overlap_words).to_a }.to_set
  end

  def clean(fields)
    cleaned = walk(fields)
    [ cleaned, cleaned != fields ]
  end

  private
    def walk(value)
      case value
      when Hash then value.transform_values { walk(it) }
      when Array then value.map { walk(it) }
      when String then without_copies(value)
      else value
      end
    end

    # Checked again once sentences are gone, as the ones either side of them may now copy a run together.
    def without_copies(text)
      sentences = matches(text, SENTENCE)
      copied = quoted(text, sentences) | overlapping(sentences)
      return text if copied.none?

      without_copies(sentences.values_at(*(sentences.each_index.to_a - copied)).map(&:first).join(" "))
    end

    # The sentences a quotation longer than quote_max_words touches, however many it spans.
    def quoted(text, sentences)
      long = matches(text, QUOTATION).filter_map { |quotation, range| range if words(quotation).size > @quote_max_words }
      sentences.each_index.select { |i| long.any? { it.overlap?(sentences[i].last) } }
    end

    # The sentences holding any of a run of overlap_words words from an excerpt, even a run across sentences.
    def overlapping(sentences)
      indexed = sentences.each_with_index.flat_map { |(sentence, _), i| words(sentence).map { [ it, i ] } }
      indexed.each_cons(@overlap_words).select { |run| @copied.include?(run.map(&:first)) }.flat_map { it.map(&:last) }.uniq
    end

    # [[text, range]] for each match.
    def matches(text, pattern)
      text.to_enum(:scan, pattern).map { Regexp.last_match }.map { [ it[0], it.begin(0)...it.end(0) ] }
    end

    # Apostrophes go ("don't" is one word); any other punctuation, a dash say, parts words as a space would.
    def words(text)
      text.downcase.gsub(/['’]/, "").gsub(/[[:punct:]]/, " ").split
    end
end
