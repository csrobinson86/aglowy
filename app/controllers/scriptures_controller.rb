# The sgid and the editor's copy of a scripture link, for the picker to insert (docs/design/scripture-links.md, Pieces).
# Signing stays on the server, so the browser never builds an sgid (Traps 4). An id that isn't a reference is a 404.
class ScripturesController < ApplicationController
  # A Bible reference isn't anyone's record and has no household, so there's nothing to authorize.
  # Signing in is still required, by ApplicationController.
  skip_after_action :verify_authorized

  def show
    reference = Bible::Reference.find(params[:id])

    render json: {
      sgid: reference.attachable_sgid,
      html: render_to_string(partial: reference.to_trix_content_attachment_partial_path, formats: :html, locals: { reference: }),
      text: reference.to_s
    }
  end
end
