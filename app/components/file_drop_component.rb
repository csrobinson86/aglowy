# frozen_string_literal: true

# The approved hand-built drop zone (CLAUDE.md, Forms): a real labelled file input, uploaded straight to
# storage by its Stimulus sidecar, which adds a hidden signed blob id named `name` for each file it uploads.
#
# blobs:          files already uploaded, kept when the form re-renders
# error:          a message from the server, shown under the zone
# submit_label:   submit the form as soon as every file is up; if one is refused, show this button instead
class FileDropComponent < ApplicationComponent
  attr_reader :name, :direct_upload_url, :blobs, :error, :submit_label

  def initialize(name:, direct_upload_url:, blobs: [], error: nil, submit_label: nil)
    @name = name
    @direct_upload_url = direct_upload_url
    @blobs = blobs
    @error = error
    @submit_label = submit_label
  end

  def input_id
    "#{name.parameterize(separator: "_")}_input"
  end

  def described_by
    [ "#{input_id}_hint", (error_id if error) ].compact.join(" ")
  end

  def error_id
    "#{input_id}_error"
  end

  def accept
    config.file_types.join(",")
  end

  def max_size
    helpers.number_to_human_size(config.max_file_size)
  end

  private
    def config
      Rails.configuration.x.family_studies
    end
end
