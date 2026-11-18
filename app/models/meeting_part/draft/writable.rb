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
  LINE_TEXT = %w[ speaker text read ].freeze
  MAX_LINES = 20
  # Sample wording needs this many lines after the checks (docs/design/meeting-parts.md, The reply).
  MIN_LINES = { demonstration: 4, talk: 2 }.freeze
  # Every string in the reply (docs/design/meeting-parts.md, The reply). The schema only describes it.
  TEXT_MAX = 500

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

    # Only the part's five details, the length to aim at, what the person typed and, for a change or sample wording, the
    # copy of the draft it builds on (Trap 2), all inside the marked block. Never the preparation, the counsel, the
    # assistant, the person's name or a household's (docs/design/ai.md, safety measure 7), and never revises itself,
    # which the purge may have taken.
    def sent_text
      part = meeting_part
      [ "Part: #{part.kind_details.label} (#{form})", "Time: #{part.minutes} minutes", ("Setting: #{part.setting_label}" if part.setting),
        "What it's about: #{part.topic}", ("Study point: #{part.study_point}" if part.study_point),
        "Aim at about #{MeetingPart::SpokenLength.target_words(part.minutes)} words.", "Write: #{outline? ? "an outline" : "sample wording"}.",
        *revised_text, ("#{change? ? "The change asked for" : "Anything else"}: #{request}" if request) ].compact.join("\n")
    end

    def form = meeting_part.kind_details.talk? ? :talk : :demonstration

    # The copy as plain text, under what it's for.
    def revised_text
      return [] unless revised_result

      [ change? ? "The draft to change:" : "The outline to write it from:", *(revised_result.key?("lines") ? wording_text : outline_text) ]
    end

    def outline_text
      outline = revised_result
      points = Array(outline["points"]).map.with_index(1) do |point, number|
        [ "Point #{number}", [ point["heading"], point["explain"], ("(#{point["scripture"]})" if point["scripture"]) ].compact_blank.join(" ") ]
      end
      [ [ "Aim", outline["aim"] ], [ "Opening", outline["opening"] ], *points, [ "Question", outline["question"] ], [ "Close", outline["close"] ],
        [ "Study point", outline["study_point"] ] ].filter_map { |label, text| "#{label}: #{text}" if text.present? }
    end

    def wording_text
      revised_result["lines"].map { "#{it["speaker"].capitalize}: #{it["text"]}#{" (Read #{it["read"]})" if it["read"]}" }
    end

    # Never the chunk's text, which is unchecked. A Stop ends the request here.
    def streamed(chunk)
      throw :stopped if self.class.stopped.exists?(id)
      return if @writing || chunk.content.blank?

      @writing = true
      progress :writing
    end

    # Off topic is settled before this. An outline needs its aim and a point after the checks; wording, its lines.
    def finish_checked(reply)
      fields = wording? ? checked_wording(reply) : checked_outline(reply)
      return finish("failed") if wording? ? fields["lines"].size < MIN_LINES[form] : fields["aim"].blank? || fields["points"].none?

      finish "drafted", result: fields,
        sources: Ai::SourceLink.keep(reply.sources, search_results: reply.search_results, allowed_hosts: purpose.allowed_hosts)
    end

    # The lines as strings, each 500 characters at most, through the same checks as an outline, then without empty lines.
    # Every line is the person's in a talk; in a demonstration a line is the other speaker's only when it says so.
    def checked_wording(reply)
      wording = reply.parsed["wording"].then { it.is_a?(Hash) ? it : {} }
      lines = Array(wording["lines"]).grep(Hash).first(MAX_LINES).map { strings(it, LINE_TEXT) }

      lines, _removed = Ai::CopyCheck.clean(Ai::ScriptureFilter.keep(lines), citations: reply.sources,
        overlap_words: purpose.copy_overlap_words, quote_max_words: purpose.quote_max_words)
      { "lines" => lines.select { it["text"].present? }.map { it.merge("speaker" => form == :demonstration && it["speaker"] == "other" ? "other" : "you") } }
    end

    # The outline's fields as strings, each 500 characters at most, without references that don't parse, web addresses or copied sentences, then
    # without empty points. Study point advice only when the person typed a study point.
    def checked_outline(reply)
      outline = reply.parsed["outline"].then { it.is_a?(Hash) ? it : {} }
      fields = strings(outline, OUTLINE_TEXT).merge("points" => Array(outline["points"]).grep(Hash).first(MAX_POINTS).map { strings(it, POINT_TEXT) })

      fields, _removed = Ai::CopyCheck.clean(Ai::ScriptureFilter.keep(fields), citations: reply.sources,
        overlap_words: purpose.copy_overlap_words, quote_max_words: purpose.quote_max_words)
      fields["points"] = fields["points"].select { it["heading"].present? || it["explain"].present? }
      meeting_part.study_point ? fields : fields.except("study_point")
    end

    # A field that isn't a string, or is longer than TEXT_MAX, is dropped, and the fields beside it stay.
    def strings(hash, keys)
      keys.index_with { hash[it].is_a?(String) && hash[it].length <= TEXT_MAX ? hash[it] : "" }
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
      broadcast_update_to self, target: [ self, :progress ], html: ApplicationController.render(partial: "family_studies/drafts/progress", locals: { step:, pages:, thing: kind_label })
    end
end
