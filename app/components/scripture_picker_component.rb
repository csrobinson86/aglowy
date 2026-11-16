# frozen_string_literal: true

# The scripture picker, rendered once, hidden, on a page with a notes editor (docs/design/scripture-links.md, The
# picker). A book list, a chapter grid and a verse grid, filled by its Stimulus sidecar from the canon data, which
# reaches the browser as JSON so the browser and the server never disagree about a chapter's verses. The Lexxy
# extension in app/javascript/lexxy/scripture_picker.js opens it and inserts what it chooses.
class ScripturePickerComponent < ApplicationComponent
  def canon
    Bible::Book.all.map(&:to_h)
  end

  # Where the picker asks the server for a reference's sgid; the sidecar puts the reference id in place of :id.
  def url
    helpers.scripture_path(":id")
  end
end
