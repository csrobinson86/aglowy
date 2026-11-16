# The tag editor's "Add a tag" input, on Primer's AutoComplete (docs/design/tags.md, The tag editor). Enter submits
# what was typed; the tag-editor controller fills the suggestions from the person's own tags in the page, so src is
# never fetched.
class Taggings::AddForm < ApplicationForm
  def initialize(src:, error: nil)
    @src = src
    @error = error
  end

  form do |f|
    # Primer 0.53.5's form input keeps visually_hide_label for itself and never passes it on to the AutoComplete,
    # whose label would show above the input. The block gets the AutoComplete before it renders, so it's set there.
    f.auto_complete(name: :name, label: "Add a tag", placeholder: "Add a tag", src: @src, size: :small, validation_message: @error) do |auto_complete|
      auto_complete.instance_variable_set(:@visually_hide_label, true)
    end
  end
end
