# Action Text's sanitizer for notes (config/application.rb). It keeps Action Text's allowed tags and attributes,
# and adds target="_blank" and rel="noopener", which a scripture link (bible/references/_reference) needs to open
# jw.org in a new tab that never gets this page as its opener: Action Text sanitizes after it renders attachments.
# A target or rel with any other value goes, so nobody can write a link that opens with this page as its opener.
class RichTextScrubber < Rails::HTML::PermitScrubber
  LINK_ATTRIBUTES = { "target" => "_blank", "rel" => "noopener" }

  # Built at the first render, once Lexxy and config/application.rb have settled the lists.
  def self.instance
    @instance ||= new
  end

  def initialize
    super
    self.tags = ActionText::ContentHelper.allowed_tags
    self.attributes = ActionText::ContentHelper.allowed_attributes + LINK_ATTRIBUTES.keys
  end

  protected
    def scrub_attributes(node)
      LINK_ATTRIBUTES.each { |name, value| node.remove_attribute(name) unless node[name].in?([ nil, value ]) }
      super
    end
end
