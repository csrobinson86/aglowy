# Rich text notes that hold scripture links and nothing else (docs/design/scripture-links.md, ScriptureLinkable).
# The editor refuses other attachments and uploads, but the browser can't be trusted: an image, a pasted
# attachment or a forged sgid for another record makes the record invalid here.
module ScriptureLinkable
  extend ActiveSupport::Concern

  class_methods do
    def scripture_linkable(name)
      validate { link_only_scriptures_in(name) }
    end
  end

  private
    # Only notes being changed are checked, so saving anything else never loads them, and notes stored before
    # this check can't block cancelling a session. Through the rich_text_ association, since the notes reader
    # builds an empty rich text that would then be saved. Finding a scripture is a parse, never a query.
    # A refused attachment leaves the unsaved notes, so the form shows again with what's left, as a refused
    # file leaves the Schedule a study list: the editor can't render another record's attachment.
    def link_only_scriptures_in(name)
      return unless association(:"rich_text_#{name}").loaded?

      rich_text = public_send(:"rich_text_#{name}")
      return unless rich_text&.changed?
      return if rich_text.body.nil? || rich_text.body.attachables.all?(Bible::Reference)

      errors.add(name, "can only link scriptures")
      rich_text.body = rich_text.body.fragment.replace(ActionText::Attachment.tag_name) do |node|
        ActionText::Attachable.from_node(node).is_a?(Bible::Reference) ? node : ""
      end.to_html
    end
end
