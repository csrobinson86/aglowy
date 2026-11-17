# One question in a personal study and its checked answer (docs/design/personal-study.md, PersonalStudy::Question).
# It's asked through PersonalStudy#ask, which makes its use: the row the person's daily count reads.
class PersonalStudy::Question < ApplicationRecord
  include Answerable

  belongs_to :personal_study
  belongs_to :user
  # Kept when the question goes (the database nulls question_id), so deleting a study can't give questions back.
  has_one :use, class_name: "Ai::Use", inverse_of: :question

  # Keep in step with the personal_study_questions_status_check constraint.
  enum :status, %w[ asking answered off_topic flagged failed stopped ].index_by(&:itself), validate: true

  encrypts :prompt, :answer

  validates :prompt, presence: true, length: { maximum: 1_000 }

  # How many questions a person may ask in a day (docs/design/ai.md, safety measure 9).
  def self.daily_limit = Ai::Purpose.find(PersonalStudy::PURPOSE).daily_limit

  # Only an answer that passed the checks can go into the notes.
  class NotAnswered < StandardError; end

  # Appends the answer to the study's notes: our own partial, every field escaped, references left as plain text for
  # link_scriptures to link, then "Pages:" and the links (docs/design/personal-study.md, Save to notes). The notes are
  # the person's record now, kept if the question goes. Under the study's lock, so two saves can't drop each other's text.
  def save_to_notes
    raise NotAnswered, "Only an answered question can be saved to notes" unless answered?

    personal_study.with_lock do
      personal_study.notes = "#{personal_study.notes&.body&.to_html}#{notes_html}"
      personal_study.link_scriptures
      personal_study.save!
    end
  end

  # A new note holding the answer, made from the same partial as save_to_notes, titled with the question cut to a
  # note title's length. It takes the study's collection when Notes uses it, and the study's tags, in color none
  # (docs/design/notes.md, Save an AI answer as a note). It's a copy: nothing links it back, so it stays if the study goes.
  def save_as_note
    raise NotAnswered, "Only an answered question can be saved as a note" unless answered?

    personal_study.user.personal_notes.new(title: prompt.squish.truncate(PersonalNote::TITLE_MAX, separator: " "), body: notes_html, color: "none",
      collection: personal_study.collection&.then { it if it.for_notes? }, tags: personal_study.tags).tap do |note|
      note.link_scriptures
      note.save!
    end
  end

  # Each paragraph of the answer escaped, so the reply's own markup is only ever text, then with its references linked
  # by Bible::Linker: what the answer card shows, and so what Scriptures in this study lists.
  def linked_paragraphs
    Array(answer&.dig("paragraphs")).map { Bible::Linker.new(ActionText::Content.new(ERB::Util.html_escape(it))).link }
  end

  def scripture_references
    linked_paragraphs.flat_map { it.attachables.grep(Bible::Reference) }
  end

  def stop
    (self.class.asking.where(id: id).update_all(status: "stopped", updated_at: Time.current) == 1).tap { reload }
  end

  private
    def notes_html
      ApplicationController.render(partial: "personal_studies/questions/notes", locals: { question: self })
    end
end
