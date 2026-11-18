# Writing a daily brief in the background (docs/design/daily-brief.md, How a writing runs), in FamilyStudy::Draft#write_now's
# five steps: moderation, then the AI under its purpose, then the checks in The reply before anyone sees a word of it,
# then the final status, written only while writing. Before each request it sends, a short read under the person's lock
# makes sure the plan isn't paused and the writing hasn't been stopped (Trap 12); the lock is never held across a request.
# Only progress lines stream while it runs, never the reply's text, and a written ending refreshes the brief's page
# (Trap 9).
module DailyBrief::Writing::Writable
  extend ActiveSupport::Concern

  # Every string in the reply (docs/design/daily-brief.md, The reply). The schema only describes it.
  TEXT_MAX = 300
  THREAD_MAX = 200
  DAILY_TEXT = %w[ reference happening teaches apply apply_scripture ].freeze
  READING = %w[ passage title ].freeze
  LOOK_FOR = %w[ verses text ].freeze
  QUALITY = %w[ name what what_scripture jesus jesus_scripture today ].freeze
  APPRECIATION = %w[ title seen scripture think ].freeze
  FOCUS = %w[ action scripture ].freeze
  EXAMPLE = %w[ name lesson scriptures ].freeze
  CHILDREN = %w[ ask today ].freeze
  EVENING = %w[ text from ].freeze
  # Fields holding one reference, and the one holding several, which go through Bible::Reference.parse (check 3).
  REFERENCE_FIELDS = %w[ reference apply_scripture passage verses what_scripture jesus_scripture scripture ].freeze
  REFERENCE_LISTS = %w[ scriptures ].freeze
  # A look-for, a faith example or an evening question with nothing left in this field after the checks is dropped.
  # Focus rows stay in place, each beside its focus area.
  ITEM_NEEDS = { "look_for" => "text", "examples" => "name", "evening" => "text" }.freeze
  # The plan's section each reply field needs; quality and appreciation need a focus area of their kind instead.
  PLAN_SECTIONS = { "daily_text" => :daily_text, "reading" => :reading, "faith" => :faith_example, "children" => :children, "evening" => :evening }.freeze
  # The brief's own sections, two of which, with the thread, make a writing (check 5).
  BRIEF_SECTIONS = %w[ daily_text reading quality appreciation focus faith ].freeze

  # A job the queue refused would leave the writing writing with nothing to write it, using one of the day's requests.
  # Active Job returns false for its own EnqueueError; Solid Queue raises its own, which it doesn't rescue. Anything
  # else ends it failed too, and is raised, as in write_now.
  def write_later
    finish "failed" unless DailyBrief::WriteJob.perform_later(id)
  rescue SolidQueue::Job::EnqueueError => error
    Rails.error.report(error)
    finish "failed"
  rescue
    finish "failed"
    raise
  end

  def write_now
    return unless may_send?
    return finish("flagged") if Ai::Moderation.flagged?(purpose.typed_text(daily_brief))
    return unless may_send?

    reply = catch(:stopped) { chat.ask_within_purpose(purpose.sent_text(daily_brief), stream: ->(chunk) { streamed(chunk) }) }
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

    # Still writing, and the person's plan isn't paused, read under the lock Plan#pause takes. Otherwise it ends stopped,
    # if nothing else ended it first, and nothing is sent.
    def may_send?
      sendable = user.with_lock { self.class.writing.exists?(id) && !daily_brief.paused? }
      sendable || stop.then { false }
    end

    # Never the chunk's text, which is unchecked. A Stop, or a pause, which stops the writing, ends the request here.
    def streamed(chunk)
      throw :stopped unless self.class.writing.exists?(id)
      return if @streaming || chunk.content.blank?

      @streaming = true
      progress :writing
    end

    # Off topic is settled before this. Then the checks in order (docs/design/daily-brief.md, The reply): copies and
    # links, references, the day's text only when its page is among the sources, and the thread and two sections.
    def finish_checked(reply)
      fields = Ai::ScriptureFilter.new(scripture_fields: REFERENCE_FIELDS, list_fields: REFERENCE_LISTS).keep(fields_from(reply.parsed))
      fields, _removed = Ai::CopyCheck.clean(fields, citations: reply.sources, overlap_words: purpose.copy_overlap_words, quote_max_words: purpose.quote_max_words)
      fields = without_empty(fields)
      sources = Ai::SourceLink.keep(reply.sources, search_results: reply.search_results, allowed_hosts: purpose.allowed_hosts)
      fields.delete("daily_text") unless sources.any? { it[:url] == daily_brief.daily_text_url }
      return finish("failed") if fields["thread"].blank? || (fields.keys & BRIEF_SECTIONS).size < 2

      finish "written", result: fields, sources: sources
    end

    # The reply's fields as strings, each 300 characters at most, for the sections this brief has: one focus row per
    # role focus area, up to 3 look-fors, 2 examples and 4 evening questions.
    def fields_from(parsed)
      reading, faith = fields_in(parsed["reading"]), fields_in(parsed["faith"])

      { "thread" => string(parsed["thread"], THREAD_MAX),
        "daily_text" => strings(parsed["daily_text"], DAILY_TEXT),
        "reading" => strings(reading, READING).merge("look_for" => items(reading["look_for"], LOOK_FOR, 3)),
        "quality" => strings(parsed["quality"], QUALITY),
        "appreciation" => strings(parsed["appreciation"], APPRECIATION),
        "focus" => items(parsed["focus"], FOCUS, daily_brief.role_areas.size),
        "faith" => strings(faith, %w[ for_me ]).merge("examples" => items(faith["examples"], EXAMPLE, 2)),
        "children" => strings(parsed["children"], CHILDREN),
        "evening" => items(parsed["evening"], EVENING, 4) }.select { |name, _| name == "thread" || wanted?(name) }
    end

    # A section that's off in the plan is ignored.
    def wanted?(name)
      case name
      when "quality" then daily_brief.quality_area.present?
      when "appreciation" then daily_brief.appreciation_area.present?
      when "focus" then daily_brief.role_areas.any?
      else daily_brief.section?(PLAN_SECTIONS.fetch(name))
      end
    end

    def fields_in(value) = value.is_a?(Hash) ? value : {}

    # A field that isn't a string, or is longer than its most (TEXT_MAX, or THREAD_MAX for the thread), is dropped, and
    # the fields beside it stay.
    def string(value, most = TEXT_MAX) = value.is_a?(String) && value.length <= most ? value : ""

    def strings(value, keys)
      fields_in(value).then { |fields| keys.index_with { string(fields[it]) } }
    end

    def items(value, keys, most)
      Array(value).grep(Hash).first(most).map { strings(it, keys) }
    end

    # Without blank strings, items missing what they need, or sections the checks left empty.
    def without_empty(value)
      case value
      when Hash then value.to_h { |key, field| [ key, ITEM_NEEDS.key?(key) ? without_empty(field).select { it[ITEM_NEEDS[key]] } : without_empty(field) ] }.compact_blank
      when Array then value.map { without_empty(it) }.then { it.all?(&:blank?) ? [] : it }
      else value.presence
      end
    end

    # Applies only while the writing is still writing, so a Stop or a pause holds, and a failed or flagged one gives back
    # its use in the same transaction, so whichever ending comes first stands and the use follows it. Only an ending
    # this wrote refreshes the page, which then shows the brief as it is: a Stop already redrew it.
    def finish(status, result: nil, sources: [])
      written = transaction do
        (self.class.writing.where(id: id).update_all(status: status, result: result, sources: sources, updated_at: Time.current) == 1).tap do
          use&.delete if it && status.in?(self.class::UNCOUNTED_STATUSES)
        end
      end

      broadcast_refresh_to self if written
    end

    # The progress lines, at +step+, to the writing's own stream (turbo_stream_from the writing), never a household's.
    def progress(step, pages: nil)
      broadcast_update_to self, target: [ self, :progress ], html: ApplicationController.render(partial: "family_studies/drafts/progress", locals: { step:, pages:, thing: "brief" })
    end
end
