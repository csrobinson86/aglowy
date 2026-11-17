# A question's answer card in a study's conversation (docs/design/personal-study.md, The study page; frame
# personal-study.png). Asking shows progress lines only, on the question's own stream, with Stop. Answered shows the
# paragraphs with their references linked, the pages used and the next questions; a not_found answer opens with its
# note. Off topic and flagged show the refusal, and nothing else from the reply. Every field is the AI's text: it's
# escaped, and references are linked by Bible::Linker after escaping, never from markup in the reply.
class PersonalStudies::AnswerComponent < ApplicationComponent
  REFUSAL = "That's outside what personal study answers. Ask about the Bible or your spiritual study.".freeze

  attr_reader :question, :household

  # household: where Stop, Save to notes and Save as a note post. The job's broadcast has none. read_only: a head reading a child's
  # study (Members::PersonalStudiesController), with nothing to press and no stream. bookmarked: the owner's bookmarks
  # (User#bookmarked), for a bookmark button beside each page used; none from the broadcast or for a head reading.
  def initialize(question:, household:, read_only: false, bookmarked: nil)
    @question = question
    @household = household
    @read_only = read_only
    @bookmarked = bookmarked
  end

  def bookmark_button(source)
    BookmarkButtonComponent.new(url: source["url"], title: source["title"], source: question.personal_study, bookmarked: @bookmarked, household:) if @bookmarked && household
  end

  def read_only? = @read_only

  def answer = question.answer || {}

  def not_found? = answer["not_found"] == true

  def next_questions = answer["next_questions"] || []

  def refused? = question.off_topic? || question.flagged?

  # Escaped first, so the reply's own markup is only ever text; then its references become scripture links.
  def linked_paragraphs
    question.linked_paragraphs.map { helpers.render_action_text_content(it) }
  end

  def note_saving_path
    household_personal_study_question_note_saving_path(household_id: household, personal_study_id: question.personal_study_id, question_id: question)
  end

  def personal_note_path
    household_personal_study_question_personal_note_path(household_id: household, personal_study_id: question.personal_study_id, question_id: question)
  end

  def stop_path
    household_personal_study_question_path(household_id: household, personal_study_id: question.personal_study_id, id: question)
  end
end
