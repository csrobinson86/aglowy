# Writing a draft in the background (docs/design/meeting-parts.md, How a request runs), in FamilyStudy::Draft#write_now's
# five steps: moderation, then the AI under its purpose, then the checks in docs/design/ai.md before anyone sees a word
# of the reply, then the final status, written only while drafting, and one broadcast. Only progress lines stream while
# it runs. Every ending is written with that conditional update, and a failed or flagged one gives back its use in the
# same transaction, so whichever ending comes first stands and the use follows it.
module MeetingPart::Draft::Writable
  extend ActiveSupport::Concern

  OUTLINE_TEXT = %w[ aim opening question close study_point ].freeze
  POINT_TEXT = %w[ heading scripture explain ].freeze
  MAX_POINTS = 3

  # A job the queue refused would leave the draft drafting with nothing to write it, using one of the day's requests.
  # Active Job returns false for its own EnqueueError; Solid Queue raises its own, which it doesn't rescue.
  def write_later
    finish "failed" unless MeetingPart::WriteDraftJob.perform_later(id)
  rescue SolidQueue::Job::EnqueueError => error
    Rails.error.report(error)
    finish "failed"
  end

  # A draft stopped while its job waited, or finished already, never reaches moderation or the AI.
  def write_now
    return unless self.class.drafting.exists?(id)
    return finish("flagged") if Ai::Moderation.flagged?([ meeting_part.topic, meeting_part.study_point, request ].compact.join("\n"))

    reply = catch(:stopped) { chat.ask_within_purpose(sent_text, stream: ->(chunk) { streamed(chunk) }) }
    return unless reply

    progress :checking, pages: reply.search_results.size
    reply.off_topic? ? finish("off_topic") : finish_checked(reply)
  rescue *Ai::PROVIDER_ERRORS
    finish "failed"
  rescue
    finish "failed"
    raise
  end

  private
    def purpose
      @purpose ||= Ai::Purpose.find(chat.purpose)
    end

    # Only the part's five details, the length to aim at and what the person typed (Trap 2). Never the preparation, the
    # counsel, the assistant, the person's name or a household's (docs/design/ai.md, safety measure 7).
    def sent_text
      part = meeting_part
      [ "Part: #{part.kind_details.label} (#{part.kind_details.talk? ? "talk" : "demonstration"})", "Time: #{part.minutes} minutes",
        ("Setting: #{part.setting_label}" if part.setting), "What it's about: #{part.topic}", ("Study point: #{part.study_point}" if part.study_point),
        "Aim at about #{MeetingPart::SpokenLength.target_words(part.minutes)} words.", "Write: an #{kind}.", ("Anything else: #{request}" if request) ].compact.join("\n")
    end

    # Never the chunk's text, which is unchecked. A Stop ends the request here.
    def streamed(chunk)
      throw :stopped if self.class.stopped.exists?(id)
      return if @writing || chunk.content.blank?

      @writing = true
      progress :writing
    end

    # Off topic is settled before this. An outline needs its aim and a point after the checks.
    def finish_checked(reply)
      outline = checked_outline(reply)
      return finish("failed") if outline["aim"].blank? || outline["points"].none?

      finish "drafted", result: outline,
        sources: Ai::SourceLink.keep(reply.sources, search_results: reply.search_results, allowed_hosts: purpose.allowed_hosts)
    end

    # The outline's fields as strings, without references that don't parse, web addresses or copied sentences, then
    # without empty points. Study point advice only when the person typed a study point.
    def checked_outline(reply)
      outline = reply.parsed["outline"].then { it.is_a?(Hash) ? it : {} }
      fields = strings(outline, OUTLINE_TEXT).merge("points" => Array(outline["points"]).grep(Hash).first(MAX_POINTS).map { strings(it, POINT_TEXT) })

      fields, _removed = Ai::CopyCheck.clean(Ai::ScriptureFilter.keep(fields), citations: reply.sources,
        overlap_words: purpose.copy_overlap_words, quote_max_words: purpose.quote_max_words)
      fields["points"] = fields["points"].select { it["heading"].present? || it["explain"].present? }
      meeting_part.study_point ? fields : fields.except("study_point")
    end

    def strings(hash, keys)
      keys.index_with { hash[it].is_a?(String) ? hash[it] : "" }
    end

    # Applies only while the draft is still drafting, so a Stop holds. Then, only if this write changed the row and the
    # draft, re-read, still has the status it wrote, one broadcast tells the panel to fetch its result: the panel's
    # links are under the household it's open in, which a personal draft doesn't know.
    def finish(status, result: nil, sources: [])
      written = transaction do
        (self.class.drafting.where(id: id).update_all(status: status, result: result, sources: sources, updated_at: Time.current) == 1).tap do
          use&.delete if it && status.in?(self.class::UNCOUNTED_STATUSES)
        end
      end

      broadcast_append_to self, target: [ self, :progress ], html: ApplicationController.helpers.tag.li(hidden: true, data: { ai_panel_target: "finished" }) if written && reload.status == status
    end

    # The progress lines, at +step+, to the draft's own stream (turbo_stream_from the draft), never a household's.
    def progress(step, pages: nil)
      broadcast_update_to self, target: [ self, :progress ], html: ApplicationController.render(partial: "family_studies/drafts/progress", locals: { step:, pages: })
    end
end
