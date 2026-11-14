# Action Text and Active Storage models don't inherit from ApplicationRecord, so give them
# its UUIDv7 primary keys too (CLAUDE.md, UUIDv7 Primary Keys).
%i[ action_text_rich_text active_storage_blob active_storage_attachment active_storage_variant_record ].each do |model|
  ActiveSupport.on_load(model) do
    before_create { self.id ||= SecureRandom.uuid_v7 }
  end
end
