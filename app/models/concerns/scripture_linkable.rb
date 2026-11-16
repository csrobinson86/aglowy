# Rich text notes that hold scripture links and nothing else (docs/design/scripture-links.md, ScriptureLinkable).
# The editor refuses other attachments and uploads, but the browser can't be trusted: an image, a pasted
# attachment or a forged sgid for another record makes the record invalid here.
module ScriptureLinkable
  extend ActiveSupport::Concern

  class_methods do
    # link_scriptures links the references typed by hand in the notes, "matt 24:14" (Bible::Linker).
    # Controllers call it before saving; there's no callback.
    def scripture_linkable(name)
      validate { link_only_scriptures_in(name) }
      define_method(:link_scriptures) { link_scriptures_in(name) }
    end
  end

  private
    # Only notes being changed are linked and checked, so saving anything else never loads them, and notes stored
    # before this check can't block cancelling a session. Through the rich_text_ association, since the notes
    # reader builds an empty rich text that would then be saved.
    def changed_rich_text(name)
      rich_text = public_send(:"rich_text_#{name}") if association(:"rich_text_#{name}").loaded?
      rich_text if rich_text&.changed?
    end

    def link_scriptures_in(name)
      rich_text = changed_rich_text(name)
      rich_text.body = Bible::Linker.new(rich_text.body).link if rich_text&.body
    end

    # Finding a scripture is a parse, never a query.
    # A refused attachment leaves the unsaved notes, so the form shows again with what's left, as a refused
    # file leaves the Schedule a study list: the editor can't render another record's attachment.
    # A plain <img> is no attachment at all, so it's looked for on its own.
    def link_only_scriptures_in(name)
      rich_text = changed_rich_text(name)
      return if rich_text&.body.nil? || only_scriptures_in?(rich_text.body)

      errors.add(name, "can only link scriptures")
      rich_text.body = rich_text.body.fragment.replace("#{ActionText::Attachment.tag_name}, img") do |node|
        node.name == ActionText::Attachment.tag_name && ActionText::Attachable.from_node(node).is_a?(Bible::Reference) ? node : ""
      end.to_html
    end

    def only_scriptures_in?(body)
      body.attachables.all?(Bible::Reference) && body.fragment.find_all("img").none?
    end
end
