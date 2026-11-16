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

  def stop
    (self.class.asking.where(id: id).update_all(status: "stopped", updated_at: Time.current) == 1).tap { reload }
  end

  private
    def notes_html
      ApplicationController.render(partial: "personal_studies/questions/notes", locals: { question: self })
    end
end
