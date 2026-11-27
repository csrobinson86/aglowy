require "test_helper"

# turbo-rails marks a String passed to turbo_stream.* html_safe; config/initializers/turbo_streams.rb escapes it
# instead, so typed text is text in a Turbo Stream as it is in ERB (#451).
class TurboStreamsTest < ActionView::TestCase
  include Turbo::StreamsHelper

  test "a String is escaped" do
    render inline: %(<%= turbo_stream.update "x", "<b>hi</b>" %>)

    assert_includes rendered, "<template>&lt;b&gt;hi&lt;/b&gt;</template>"
  end

  test "a String sent to every target is escaped too" do
    render inline: %(<%= turbo_stream.update_all ".x", "<b>hi</b>" %>)

    assert_includes rendered, "<template>&lt;b&gt;hi&lt;/b&gt;</template>"
  end

  test "a String already escaped by h() or safe_join isn't escaped twice" do
    render inline: %(<%= turbo_stream.update "x", h("<b>hi</b>") %><%= turbo_stream.update "y", safe_join([ "a & b", "c" ], " · ") %>)

    assert_includes rendered, "<template>&lt;b&gt;hi&lt;/b&gt;</template>"
    assert_includes rendered, "<template>a &amp; b · c</template>"
  end

  test "HTML marked safe, a component, a partial and a block render as HTML" do
    reference = Bible::Reference.find("19:37:8-9")

    render inline: <<~ERB, locals: { reference: }
      <%= turbo_stream.update "safe", tag.b("safe") %>
      <%= turbo_stream.update "component", Primer::Beta::Text.new(tag: :b).with_content("component") %>
      <%= turbo_stream.update "partial", partial: "bible/references/reference", locals: { reference: } %>
      <%= turbo_stream.update("block") { tag.b("block") } %>
    ERB

    assert_dom "turbo-stream[target=safe] template b", text: "safe"
    assert_dom "turbo-stream[target=component] template b", text: "component"
    assert_dom "turbo-stream[target=partial] template a.scripture-link", text: "Psalm 37:8, 9"
    assert_dom "turbo-stream[target=block] template b", text: "block"
  end

  # The guard overrides a private turbo-rails method; this fails if an upgrade renames it.
  test "the guard sits in front of turbo-rails' render_template" do
    assert_includes Turbo::Streams::TagBuilder.ancestors, Turbo::Streams::EscapedContent
    assert_includes Turbo::Streams::TagBuilder.private_instance_methods(false), :render_template
    assert_includes Turbo::Streams::EscapedContent.private_instance_methods(false), :render_template
  end
end
