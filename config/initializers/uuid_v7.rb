# Action Text and Active Storage models don't inherit from ApplicationRecord, so give them
# its UUIDv7 primary keys too (CLAUDE.md, UUIDv7 Primary Keys).
%i[ action_text_rich_text active_storage_blob active_storage_attachment active_storage_variant_record ].each do |model|
  ActiveSupport.on_load(model) do
    before_create { self.id ||= SecureRandom.uuid_v7 }
  end
end

# RubyLLM's own records (models, usage, tool calls) have their own base class. Its model registry is written
# with upsert_all, which runs no callbacks, so each row gets its id here. An upsert never rewrites a primary key,
# so a model already in the table keeps its id.
module UuidV7Upserts
  def upsert_all(attributes, **)
    super(attributes.map { { id: SecureRandom.uuid_v7 }.merge(it) }, **)
  end
end

ActiveSupport.on_load(:active_record) do
  RubyLLM::ActiveRecord::Record.before_create { self.id ||= SecureRandom.uuid_v7 }
  RubyLLM::ActiveRecord::Record.singleton_class.prepend UuidV7Upserts
end
