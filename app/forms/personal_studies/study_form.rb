# A study's title and collection: the whole New study page, and the Rename and Move to collection Dialogs on a study,
# which show one field each. The collection select offers "None" and the person's collections for Personal study.
class PersonalStudies::StudyForm < ApplicationForm
  # fields: which of :title and :collection to show. collections: the choices for :collection.
  def initialize(submit_label:, fields: %i[ title collection ], collections: [], cancel_path: nil)
    @submit_label = submit_label
    @fields = fields
    @collections = collections
    @cancel_path = cancel_path
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
    f.group(layout: :horizontal) do |actions|
      actions.submit(name: :submit, label: @submit_label, scheme: :primary)
      actions.button(name: :cancel, label: "Cancel", tag: :a, href: @cancel_path, scheme: :link, align_self: :center) if @cancel_path
    end
  end
end
