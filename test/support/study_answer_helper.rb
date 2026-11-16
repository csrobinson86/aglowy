# Answering a personal study's question in a system test (docs/design/personal-study.md, Asking). The test queue
# adapter only enqueues the question's job; answer runs it here with the AI stubbed, so nothing calls an AI provider.
module StudyAnswerHelper
  include ActiveJob::TestHelper

  private
    # A question's card, by its question: an earlier answer's "Keep digging" chip can have the same words.
    def question_card(prompt)
      find(".study-question") { it.has_selector?("p", exact_text: prompt, wait: false) }
    end

    # Runs the question's job here, with moderation passing and Chat#ask_within_purpose standing in for the provider:
    # it streams the saved reply's text (test/fixtures/files/ai/), calls +midway+ after the first chunk, then answers
    # with the saved reply as the provider's HTTP response would arrive. No test calls a provider.
    def answer(name, midway: -> { })
      question = PersonalStudy::Question.asking.sole
      chat = question.personal_study.chat
      ask_for_real = chat.method(:ask_within_purpose)
      body = JSON.parse(file_fixture("ai/#{name}.json").read)
      ask = lambda do |text, stream:|
        body["content"].filter_map { it["text"] }.each_with_index do |chunk, index|
          stream.call(RubyLLM::Chunk.new(role: :assistant, content: chunk))
          midway.call if index.zero?
        end
        response = Faraday::Response.new(Faraday::Env.from(status: 200, body: body))
        chat.to_llm.provider.connection.stub(:post, ->(*, **) { response }) { ask_for_real.call(text) }
      end

      Ai::Moderation.stub(:flagged?, false) do
        chat.stub(:ask_within_purpose, ask) do
          PersonalStudy::Question.stub(:find_by, question) { perform_enqueued_jobs }
        end
      end
    end
end
