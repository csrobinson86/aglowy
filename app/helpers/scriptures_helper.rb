module ScripturesHelper
  # The options on every notes rich_text_area, so both notes editors stay the same (docs/design/scripture-links.md,
  # Editor options). Scripture links are the one attachment Lexxy lets in; attachments: false would refuse them too
  # (Traps 1). Uploads stay off: no upload URLs, no upload buttons (components/_lexxy.scss), and the no-uploads
  # controller refuses every file. A refused note points its editor at the message from scriptures/_notes_validation.
  def scripture_notes_options(form)
    {
      "permitted-attachment-types": Bible::Reference::CONTENT_TYPE,
      "remote-images": false,
      toolbar: { upload: "none" }.to_json,
      aria: ({ invalid: true, describedby: form.field_id(:notes, :validation) } if form.object.errors.include?(:notes)),
      data: { direct_upload_url: "", blob_url_template: "", controller: "no-uploads", action: "lexxy:file-accept->no-uploads#refuse" }
    }.compact
  end
end
