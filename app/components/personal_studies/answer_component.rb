# A question's answer card in a study's conversation (docs/design/personal-study.md, The study page; frame
# personal-study.png). Asking shows progress lines only, on the question's own stream, with Stop. Answered shows the
# paragraphs with their references linked, the pages used and the next questions; a not_found answer opens with its
# note. Off topic and flagged show the refusal, and nothing else from the reply. Every field is the AI's text: it's
# escaped, and references are linked by Bible::Linker after escaping, never from markup in the reply.
class PersonalStudies::AnswerComponent < ApplicationComponent
  REFUSAL = "That's outside what personal study answers. Ask about the Bible or your spiritual study.".freeze

  attr_reader :question, :household

  # household: where Stop and Save to notes post. The job's broadcast has none. read_only: a head reading a child's
  # study (Members::PersonalStudiesController), with nothing to press and no stream.
  def initialize(question:, household:, read_only: false)
    @question = question
    @household = household
    @read_only = read_only
  end

  def read_only? = @read_only

  def answer = question.answer || {}

  def not_found? = answer["not_found"] == true

  def paragraphs = answer["paragraphs"] || []

  def next_questions = answer["next_questions"] || []

  def refused? = question.off_topic? || question.flagged?

  # Escaped first, so the reply's own markup is only ever text; then its references become scripture links.
  def linked(paragraph)
    helpers.render_action_text_content(Bible::Linker.new(ActionText::Content.new(ERB::Util.html_escape(paragraph))).link)
  end

  def note_saving_path
    household_personal_study_question_note_saving_path(household_id: household, personal_study_id: question.personal_study_id, question_id: question)
  end

  def stop_path
    household_personal_study_question_path(household_id: household, personal_study_id: question.personal_study_id, id: question)
  end
end
