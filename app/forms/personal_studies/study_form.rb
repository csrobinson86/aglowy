# A study's title and collection: the whole New study page, and the Rename and Move to collection Dialogs on a study,
# which show one field each. The collection select offers "None" and the person's collections for Personal study.
# The New study page adds a first question, asked as the study starts, for someone who can ask the AI.
class PersonalStudies::StudyForm < ApplicationForm
  # fields: which of :title, :collection and :question to show. collections: the choices for :collection.
  # first_question: what was typed in :question, when the form is shown again.
  def initialize(submit_label:, fields: %i[ title collection ], collections: [], cancel_path: nil, first_question: nil)
    @submit_label = submit_label
    @fields = fields
    @collections = collections
    @cancel_path = cancel_path
    @first_question = first_question
  end

  form do |f|
    if @fields.include?(:title)
      f.text_field(name: :title, label: "Title", required: true, full_width: true, maxlength: 120,
                   caption: ("A question or a topic you'd like to research." if @cancel_path))
    end
    if @fields.include?(:collection)
      f.select_list(name: :collection_id, label: "Collection", include_blank: "None") do |list|
        @collections.each { |collection| list.option(label: collection.name, value: collection.id) }
      end
    end
    if @fields.include?(:question)
      f.text_area(name: :prompt, label: "First question", character_limit: 1_000, rows: 3, full_width: true, value: @first_question,
                  caption: "Optional. It's asked as the study starts, with answers from jw.org and wol.jw.org.")
    end
    f.group(layout: :horizontal) do |actions|
      actions.submit(name: :submit, label: @submit_label, scheme: :primary)
      actions.button(name: :cancel, label: "Cancel", tag: :a, href: @cancel_path, scheme: :link, align_self: :center) if @cancel_path
    end
  end
end
