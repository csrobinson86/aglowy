# One person's saved jw.org page or scripture, to come back to from Notes' Bookmarks tab (docs/design/bookmarks.md,
# Bookmark). Personal and private: it follows the person between households, and nobody else ever sees it. A page's
# title came from an AI search result, so it's untrusted text, escaped wherever it's shown.
class Bookmark < ApplicationRecord
  # The sites the AI is allowed to search (docs/design/ai.md), and so the only pages a bookmark can hold.
  HOSTS = %w[ jw.org www.jw.org wol.jw.org ].freeze
  LIMIT = 2_000
  TITLE_MAX = 120
  COMMENT_MAX = 280

  belongs_to :user
  # The study or note it was saved from, while that still exists: deleting one nullifies this (dependent: :nullify).
  belongs_to :source, polymorphic: true, optional: true

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

  validates :title, length: { maximum: TITLE_MAX }
  validates :comment, length: { maximum: COMMENT_MAX }
  validate :page_or_scripture
  validate :scripture_exists, if: :scripture
  # A page the person already has doesn't count, so a create that races another to it reaches the unique index.
  validate(on: :create) { errors.add(:base, "You already have #{LIMIT.to_fs(:delimited)} bookmarks, the most you can have") if user && user.bookmarks.count >= LIMIT && !user.bookmark_for(url:, scripture:) }

  scope :preloaded, -> { includes(:source) }
  scope :pages, -> { where.not(url: nil) }
  scope :scriptures, -> { where.not(scripture: nil) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

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

  def scripture_exists
    Bible::Reference.find(scripture)
  rescue ActiveRecord::RecordNotFound
    errors.add(:scripture, "isn't a Bible reference")
  end
end
