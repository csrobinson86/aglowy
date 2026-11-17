# One person's saved jw.org page or scripture, to come back to from Notes' Bookmarks tab (docs/design/bookmarks.md,
# Bookmark). Personal and private: it follows the person between households, and nobody else ever sees it. A page's
# title came from an AI search result, so it's untrusted text, escaped wherever it's shown.
class Bookmark < ApplicationRecord
  include Taggable

  # The sites the AI is allowed to search (docs/design/ai.md), and so the only pages a bookmark can hold.
  HOSTS = %w[ jw.org www.jw.org wol.jw.org ].freeze
  LIMIT = 2_000
  TITLE_MAX = 120
  COMMENT_MAX = 280

  belongs_to :user
  # The study or note it was saved from, while that still exists: deleting one nullifies this (dependent: :nullify).
  belongs_to :source, polymorphic: true, optional: true
  # One of the person's collections for Notes, or none. The database takes a deleted collection's out (on_delete: :nullify).
  belongs_to :collection, optional: true

  # Personal text (docs/product/vision.md, Private by default). Non-deterministic, like Goal's, so never searched in SQL.
  encrypts :title, :comment

  # https only, no fragment and no utm_ parameters, so the same page saved twice is the same row. Anything else is nil.
  normalizes :url, with: -> { Ai::SourceLink.new(it, allowed_hosts: HOSTS).url }
  # The reference's own id, so "19:23:4-4" and "19:23:4" are one row. One that isn't a reference stays as it came, for
  # scripture_exists to refuse.
  normalizes :scripture, with: -> do
    Bible::Reference.find(it).id
  rescue ActiveRecord::RecordNotFound
    it
  end

  # A page's title can be renamed but never emptied; one saved without a title can stay without.
  normalizes :title, with: -> { it.squish.presence }
  normalizes :comment, with: -> { it.strip.presence }

  validates :title, length: { maximum: TITLE_MAX }
  validates :title, presence: true, if: -> { url && will_save_change_to_title? }
  validates :comment, length: { maximum: COMMENT_MAX }
  validate :page_or_scripture
  validate :scripture_exists, if: :scripture
  validate :collection_usable, if: :collection
  # A page the person already has doesn't count, so a create that races another to it reaches the unique index.
  validate(on: :create) { errors.add(:base, "You already have #{LIMIT.to_fs(:delimited)} bookmarks, the most you can have") if user && user.bookmarks.count >= LIMIT && !user.bookmark_for(url:, scripture:) }

  scope :preloaded, -> { includes(:source, :collection, :tags) }
  scope :pages, -> { where.not(url: nil) }
  scope :scriptures, -> { where.not(scripture: nil) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  # Called on a person's bookmarks: user.bookmarks.matching("comfort"). Collection names, tag names and a scripture's
  # book are searched in SQL; titles and comments are encrypted, so they're matched in Ruby on the decrypted values,
  # never in SQL. A person has at most 2,000 bookmarks, so loading theirs is fine (docs/design/bookmarks.md, Bookmark).
  def self.matching(text)
    text = text.to_s.squish
    in_ruby = select(:id, :title, :comment).filter { it.mentions?(text) }.map(&:id)
    where(id: matching_in_sql(text).ids | in_ruby)
  end

  # "#Comfort" finds the comfort tag, as Tag.normalize makes it; "Ps" finds Psalms. % and _ are plain characters.
  def self.matching_in_sql(text)
    term, tag_name = "%#{sanitize_sql_like(text)}%", Tag.normalize(text)
    found = where(collection: Collection.where(Collection.arel_table[:name].matches(term)))
    unless tag_name.empty?
      tags = Tag.where(Tag.arel_table[:name].matches("%#{sanitize_sql_like(tag_name)}%"))
      found = found.or(where(id: Tagging.where(taggable_type: polymorphic_name, tag: tags).select(:taggable_id)))
    end
    books = Bible::Book.normalize(text).empty? ? [] : Bible::Book.match(text)
    books.reduce(found) { |relation, book| relation.or(where(arel_table[:scripture].matches("#{book.number}:%"))) }
  end
  private_class_method :matching_in_sql

  # Whether the decrypted title or comment holds the text, ignoring case.
  def mentions?(text)
    [ title, comment ].any? { it&.downcase&.include?(text.downcase) }
  end

  def kind
    url ? :page : :scripture
  end

  # The scripture's Bible reference, which views show (to_s) and link (jw_url); nil for a page.
  def reference
    Bible::Reference.find(scripture) if scripture
  end

  # What User#bookmarked holds it by: the normalized URL, or the scripture's reference id.
  def key
    url || scripture
  end

  private

  # A URL the normalizer turned into nil is a page on another site, or not https.
  def page_or_scripture
    if url_came_in_but_was_refused?
      errors.add(:url, "must be a page on jw.org or wol.jw.org")
    elsif [ url, scripture ].compact.size != 1
      errors.add(:base, "A bookmark is a page or a scripture")
    end
  end

  def url_came_in_but_was_refused?
    url.nil? && url_before_type_cast.present?
  end

  # The database can't check either across tables (docs/design/bookmarks.md, Bookmark).
  def collection_usable
    if collection.user_id != user_id
      errors.add(:collection, "isn't one of yours")
    elsif !collection.for_notes?
      errors.add(:collection, "is only used in Personal study")
    end
  end

  def scripture_exists
    Bible::Reference.find(scripture)
  rescue ActiveRecord::RecordNotFound
    errors.add(:scripture, "isn't a Bible reference")
  end
end
