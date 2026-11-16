# SimpleCov must start before anything loads app code, or early files go uncounted.
require "simplecov"
# Judge the gate on a full `bin/rails test:all`; a partial run falls short of 100%.
SimpleCov.start "rails" do
  enable_coverage :branch
  minimum_coverage line: 100
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# List every file under app/ in the report, whether or not CI turns on eager loading.
Rails.application.eager_load!

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Give each worker its own SimpleCov result so they merge instead of overwriting.
    parallelize_setup    { |worker| SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}" }
    parallelize_teardown { |_worker| SimpleCov.result }

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # A file as the drop zone leaves it: a blob created with the browser's declared type, then uploaded.
    def direct_uploaded_blob(name, filename: name)
      file = file_fixture(name)
      ActiveStorage::Blob.create_before_direct_upload!(filename: filename, byte_size: file.size, checksum: OpenSSL::Digest::MD5.base64digest(file.binread),
                                                       content_type: Marcel::MimeType.for(name: filename)).tap { it.upload_without_unfurling(file.open) }
    end

    # The home household's only file is the study_guide fixture, so its stored size is all the household uses.
    # Only the size column changes: never write gigabytes to disk.
    def use_home_storage(bytes)
      active_storage_blobs(:study_guide).update_column(:byte_size, bytes)
    end

    # Attachments in notes HTML, as Lexxy saves them (docs/design/scripture-links.md, ScriptureLinkable).
    def scripture_attachment(id)
      reference = Bible::Reference.find(id)
      %(<action-text-attachment sgid="#{reference.attachable_sgid}" content-type="#{reference.attachable_content_type}"></action-text-attachment>)
    end

    # Another record's sgid, signed for attachments: a forged scripture link.
    def foreign_attachment(record)
      %(<action-text-attachment sgid="#{record.to_sgid(for: ActionText::Attachable::LOCATOR_NAME)}" content-type="application/vnd.actiontext.scripture"></action-text-attachment>)
    end

    def remote_image_attachment
      %(<action-text-attachment url="https://example.com/cat.png" content-type="image/png"></action-text-attachment>)
    end

    # A family study draft with its own chat, as FamilyStudy::Draft.start leaves one, without asking the AI.
    def family_study_draft(household: households(:home), user: users(:head), **attributes)
      chat = Chat.create!(user: user, household: household, purpose: "family_study_draft")
      FamilyStudy::Draft.create!(household: household, user: user, chat: chat, prompt: "Prayer as a family", length_minutes: 30, **attributes)
    end

    # A plain image, no attachment at all, as a crafted request could send.
    def image_tag_html
      %(<img src="https://example.com/cat.png">)
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end
