# turbo_stream.update("id", text) and every other turbo_stream.* action mark a plain String html_safe: turbo-rails
# 2.0.23 hands it back from Turbo::Streams::TagBuilder#render_template, and turbo_stream_action_tag calls
# template.to_s.html_safe. So typed text in a stream ran as HTML (#451). This escapes a String first, as ERB does;
# html_escape leaves an html_safe String (h(), safe_join, tag.*) alone, and partials, components and blocks don't
# pass through it. render_template is private: test/helpers/turbo_streams_test.rb fails if an upgrade renames it.
module Turbo::Streams::EscapedContent
  private

  def render_template(target, content = nil, **, &)
    super(target, content.is_a?(String) ? ERB::Util.html_escape(content) : content, **, &)
  end
end

ActiveSupport.on_load(:turbo_streams_tag_builder) { prepend Turbo::Streams::EscapedContent }
