# Writing a draft in the background (docs/design/family-studies.md, FamilyStudy::Draft): moderation, then the AI
# under its purpose, then the checks in docs/design/ai.md before anyone sees a word of the reply. Only progress lines
# stream while it runs; the checked result replaces the panel once, and never over a Stop.
module FamilyStudy::Draft::Writable
  extend ActiveSupport::Concern

  # The provider's errors, the connection's once RubyLLM's retries run out, and a reply that isn't a JSON object.
  PROVIDER_ERRORS = [ RubyLLM::Error, Faraday::Error, Ai::Reply::Malformed ].freeze
  OUTLINE_FIELDS = %w[ title opening points children closing ].freeze
  MINIMUM_POINTS = 2

  # A job the queue refused would leave the draft drafting with nothing to write it, using one of the day's drafts.
  # perform_later returns false then (Active Job rescues the EnqueueError), so the draft fails and doesn't count.
  def write_later
    finish "failed" unless FamilyStudy::WriteDraftJob.perform_later(id)
  end

  # A draft stopped while its job waited, or finished already, never reaches moderation or the AI.
  def write_now
    return unless self.class.drafting.exists?(id)
    return finish("flagged") if Ai::Moderation.flagged?(prompt)

    progress "Searching jw.org and wol.jw.org…"
    reply = catch(:stopped) { chat.ask_within_purpose(request, stream: ->(chunk) { streamed(chunk) }) }
    return unless reply

    progress "Checking scriptures, links and wording…"
    reply.off_topic? ? finish("off_topic") : finish_checked(reply)
  rescue *PROVIDER_ERRORS
    finish("failed")
  rescue
    finish("failed")
    raise
  end

  private
    def purpose
      @purpose ||= Ai::Purpose.find(chat.purpose)
    end

    # Only what the person typed and the options they chose (docs/design/ai.md, safety measure 7).
    def request
      [ prompt, "", "Length: #{length_minutes} minutes.", ("Include one activity for young children." if young_children?) ].compact.join("\n")
    end

    # Never the chunk's text, which is unchecked. A Stop ends the request here.
    def streamed(chunk)
      throw :stopped if self.class.stopped.exists?(id)
      return if @writing || chunk.content.blank?

      @writing = true
      progress "Writing the outline…"
    end

    def finish_checked(reply)
      outline = checked_outline(reply)
      return finish("failed") if outline["points"].size < MINIMUM_POINTS

      finish "drafted", outline: outline,
        sources: Ai::SourceLink.keep(reply.sources, search_results: reply.search_results, allowed_hosts: purpose.allowed_hosts)
    end

    # The reply's fields with bad references, web addresses and copied sentences gone, and any point left empty.
    def checked_outline(reply)
      fields = Ai::ScriptureFilter.keep(reply.parsed.slice(*OUTLINE_FIELDS))
      fields, _removed = Ai::CopyCheck.clean(fields, citations: reply.sources, overlap_words: purpose.copy_overlap_words, quote_max_words: purpose.quote_max_words)
      fields["points"] = Array(fields["points"]).select { it.is_a?(Hash) && (it["heading"].present? || it["question"].present?) }
      young_children? ? fields : fields.except("children")
    end

    # Applies only while the draft is still drafting, so a Stop during the checks holds. The result replaces the
    # panel only if this write changed the row and the draft, re-read, still has the status it wrote.
    def finish(status, outline: nil, sources: [])
      written = self.class.drafting.where(id: id).update_all(status: status, outline: outline, sources: sources, updated_at: Time.current) == 1
      broadcast_replace_to self, partial: "family_studies/drafts/draft", locals: { draft: self } if written && reload.status == status
    end

    # To the draft's own stream (turbo_stream_from the draft), never a household's.
    def progress(line)
      broadcast_update_to self, target: [ self, :progress ], html: ERB::Util.html_escape(line)
    end
end
