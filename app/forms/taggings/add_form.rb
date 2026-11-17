# The tag editor's "Add a tag" input, on Primer's AutoComplete (docs/design/tags.md, The tag editor). Enter submits
# what was typed; the tag-editor controller fills the suggestions from the person's own tags in the page, so src is
# never fetched. input_id keeps each editor's input apart when a page has several, as the Bookmarks tab's dialogs do.
class Taggings::AddForm < ApplicationForm
  def initialize(src:, input_id:, error: nil)
    @src = src
    @input_id = input_id
    @error = error
  end

  form do |f|
    # Primer 0.53.5's form input keeps visually_hide_label for itself and never passes it on to the AutoComplete,
    # whose label would show above the input. It also takes the input's id from the field name alone, ignoring the
    # form's namespace, so every editor's input would be "name" and only the first labelled. The block gets the
    # AutoComplete before it renders, so both are set there.
    f.auto_complete(name: :name, label: "Add a tag", placeholder: "Add a tag", src: @src, size: :small, validation_message: @error) do |auto_complete|
      auto_complete.instance_variable_set(:@visually_hide_label, true)
      auto_complete.instance_variable_set(:@input_id, @input_id)
      auto_complete.instance_variable_set(:@list_id, "#{@input_id}-list")
      auto_complete.instance_variable_get(:@system_arguments)[:for] = "#{@input_id}-list"
    end
  end
end
