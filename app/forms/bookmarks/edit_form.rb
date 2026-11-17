# A bookmark's own title (pages only), comment and collection, then Save, in its Edit dialog (frame bookmark-edit.png).
# The tag editor follows it with forms of its own, which save each tag at once. A refused save comes back with each
# reason by its field; the collection's is on collection, not collection_id.
class Bookmarks::EditForm < ApplicationForm
  def initialize(page:, collections:, collection_error: nil)
    @page = page
    @collections = collections
    @collection_error = collection_error
  end

  form do |f|
    f.text_field(name: :title, label: "Title", required: true, full_width: true, maxlength: Bookmark::TITLE_MAX) if @page
    f.text_area(name: :comment, label: "Comment (optional)", caption: "Up to #{Bookmark::COMMENT_MAX} characters.", full_width: true, maxlength: Bookmark::COMMENT_MAX)
    f.select_list(name: :collection_id, label: "Collection", include_blank: "None", validation_message: @collection_error) do |list|
      @collections.each { |collection| list.option(label: collection.name, value: collection.id) }
    end
    f.submit(name: :submit, label: "Save", scheme: :primary)
  end
end
