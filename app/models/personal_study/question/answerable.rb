# Answering a question in the background (docs/design/personal-study.md, Asking): moderation, then the AI under its
# purpose in the study's chat, then the checks in docs/design/ai.md before anyone sees a word of the reply. Only
# progress lines stream while it runs; the checked answer replaces the question once, and never over a Stop.
module PersonalStudy::Question::Answerable
  extend ActiveSupport::Concern

  ANSWER_FIELDS = %w[ not_found not_found_note paragraphs next_questions ].freeze
  MAX_PARAGRAPHS = 5
  MAX_NEXT_QUESTIONS = 3
  YOUNG_READER = "The reader is young: write simply, for a young reader.".freeze
  # The ones that don't count toward the day's questions (docs/design/ai.md, safety measure 9).
  UNCOUNTED_STATUSES = %w[ flagged failed ].freeze

  # A job the queue refused would leave the question asking with nothing to answer it, using one of the day's
  # questions. Active Job returns false for its own EnqueueError; Solid Queue raises its own, which it doesn't rescue.
  def answer_later
    finish "failed" unless PersonalStudy::AnswerQuestionJob.perform_later(id)
  rescue SolidQueue::Job::EnqueueError => error
    Rails.error.report(error)
    finish "failed"
  end

  # A question stopped while its job waited, or finished already, never reaches moderation or the AI.
  def answer_now
    return unless self.class.asking.exists?(id)
    return finish("flagged") if Ai::Moderation.flagged?(prompt)

    reply = catch(:stopped) { personal_study.chat.ask_within_purpose(request, stream: ->(chunk) { streamed(chunk) }) }
    return unless reply

    progress :checking
    reply.off_topic? ? finish("off_topic") : finish_checked(reply)
  rescue *Ai::PROVIDER_ERRORS
    finish "failed"
  rescue
    finish "failed"
    raise
  end

  private
    def purpose
      @purpose ||= Ai::Purpose.find(personal_study.chat.purpose)
    end

    # Only what the person typed, and who's reading (docs/design/ai.md, safety measure 7).
    def request
      [ prompt, (YOUNG_READER if young_reader?) ].compact.join("\n\n")
    end

    # Never the chunk's text, which is unchecked. A Stop ends the request here.
    def streamed(chunk)
      throw :stopped if self.class.stopped.exists?(id)
      return if @writing || chunk.content.blank?

      @writing = true
      progress :writing
    end

    # Off topic is settled before this. Any other answer needs a paragraph or a not_found note after the checks.
    def finish_checked(reply)
      answer = checked_answer(reply)
      return finish("failed") if answer["paragraphs"].none? && answer["not_found_note"].blank?

      finish "answered", answer: answer,
        sources: Ai::SourceLink.keep(reply.sources, search_results: reply.search_results, allowed_hosts: purpose.allowed_hosts)
    end

    # The reply's fields without blank paragraphs (removed before any other check), web addresses or copied sentences.
    def checked_answer(reply)
      fields = reply.parsed.slice(*ANSWER_FIELDS)
      fields["not_found"] = fields["not_found"] == true
      fields["not_found_note"] = fields["not_found"] ? fields["not_found_note"].to_s : ""
      fields["paragraphs"] = strings(fields["paragraphs"]).first(MAX_PARAGRAPHS)
      fields["next_questions"] = strings(fields["next_questions"]).first(MAX_NEXT_QUESTIONS)

      fields, _removed = Ai::CopyCheck.clean(Ai::ScriptureFilter.keep(fields), citations: reply.sources,
        overlap_words: purpose.copy_overlap_words, quote_max_words: purpose.quote_max_words)
      fields.merge("paragraphs" => fields["paragraphs"].compact_blank, "next_questions" => fields["next_questions"].compact_blank)
    end

    def strings(value)
      Array(value).select { it.is_a?(String) && it.strip.present? }
    end

    # Applies only while the question is still asking, so a Stop during the checks holds. A failed or flagged question
    # gives back its use in the same transaction. The result replaces the question only if this write changed the row
    # and the question, re-read, still has the status it wrote.
    def finish(status, answer: nil, sources: [])
      written = transaction do
        (self.class.asking.where(id: id).update_all(status: status, answer: answer, sources: sources, updated_at: Time.current) == 1).tap do
          use&.delete if it && status.in?(UNCOUNTED_STATUSES)
        end
      end

      broadcast_result if written && reload.status == status
    end

    # An answer's pages join the study's counts and sources first: the page stops listening once the question it
    # listens on is replaced.
    def broadcast_result
      if answered?
        %w[ counts sources ].each do |part|
          broadcast_replace_to self, target: [ personal_study, part ],
            html: ApplicationController.render(partial: "personal_studies/#{part}", locals: { personal_study: })
        end
      end
      broadcast_replace_to self, target: self, partial: "personal_studies/questions/question", locals: { question: self }
    end

    # The progress lines, at +step+, to the question's own stream (turbo_stream_from the question), never a household's.
    def progress(step)
      broadcast_update_to self, target: [ self, :progress ], html: ApplicationController.render(partial: "personal_studies/questions/progress", locals: { step: })
    end
end
