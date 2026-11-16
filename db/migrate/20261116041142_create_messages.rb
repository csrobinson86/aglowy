class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    # RubyLLM's messages without its citations, server_tool_calls, raw_content and raw_reasoning columns: those
    # hold search results and cited_text, which Aglowy never stores (docs/design/ai.md, Links the AI used).
    # RubyLLM skips a column the table doesn't have. content is encrypted, so it's text.
    create_table :messages, id: :uuid do |t|
      t.references :chat, null: false, foreign_key: { to_table: :chats }, type: :uuid
      t.string :role, null: false
      t.text :content
      t.boolean :cache_until_here, null: false, default: false
      t.string :cache_ttl
      t.text :thinking_text
      t.text :thinking_signature
      t.string :phase
      t.text :continuation
      t.string :finish_reason
      t.timestamps
    end
  end
end
