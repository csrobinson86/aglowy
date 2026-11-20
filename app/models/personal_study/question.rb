# One question in a personal study and its checked answer (docs/design/personal-study.md, PersonalStudy::Question).
# It's asked through PersonalStudy#ask, which makes its use: the row the person's daily count reads.
class PersonalStudy::Question < ApplicationRecord
  include Answerable

  belongs_to :personal_study
  belongs_to :user
  # Kept when the question goes (the database nulls question_id), so deleting a study can't give questions back.
  has_one :use, class_name: "Ai::Use", inverse_of: :question
  # The database deletes it with the question or the note.
  has_one :note_saving, inverse_of: :question

  # Keep in step with the personal_study_questions_status_check constraint.
  enum :status, %w[ asking answered off_topic flagged failed stopped ].index_by(&:itself), validate: true

  encrypts :prompt, :answer

  validates :prompt, presence: true, length: { maximum: 1_000 }

  # How many questions a person may ask in a day (docs/design/ai.md, safety measure 9).
  def self.daily_limit = Ai::Purpose.find(PersonalStudy::PURPOSE).daily_limit

  # Only an answer that passed the checks can go into the note.
  class NotAnswered < StandardError; end

  # Appends the answer to the study's note, making the note on the first save: our own partial, every field escaped,
  # the question as a heading, references left as plain text for link_scriptures to link, then "Pages:" and the links
  # (docs/design/personal-study.md, Save to note). Under the study's lock, so Start a note and another save find the
  # same note, then the note's, so it can't change between reading the body and writing it. The save moves the note's
  # updated_at, so an editor opened before it can't remove the answer. An answer already in the note changes nothing.
  def save_to_note
    raise NotAnswered, "Only an answered question can be saved to the note" unless answered?

    personal_study.with_lock do
      personal_study.start_note.tap do |note|
        note.with_lock do
          next if reload_note_saving

          note.body = "#{note.body&.body&.to_html}#{note_html}"
          note.link_scriptures
          note.save!
          create_note_saving!(personal_note: note)
        end
      end
    end
  end

  def saved_to_note?
    note_saving.present?
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
    def note_html
      ApplicationController.render(partial: "personal_studies/questions/note", locals: { question: self })
    end
end
