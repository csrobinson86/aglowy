# frozen_string_literal: true

# One bag in Go bags (frame go-bags.png): its icon, its name, and one muted line with where it's kept and how many
# things are to buy, or "All ready". A child, who can't change it, sees how ready it is instead ("2 of 3 ready").
# The whole row opens the bag. Pass a bag from GoBag.preloaded, so a list asks no query per bag.
class GoBagRowComponent < ApplicationComponent
  attr_reader :go_bag, :today

  # today: the household's (household.today). read_only: the viewer can't change the bag.
  def initialize(go_bag:, today:, read_only: false)
    @go_bag = go_bag
    @today = today
    @read_only = read_only
  end

  def line
    [ ("Kept in #{go_bag.kept_at}" if go_bag.kept_at.present?), status ].compact.join(" · ")
  end

  private
    def status
      if go_bag.items_count.zero?
        "No items yet"
      elsif @read_only
        "#{go_bag.ready_count} of #{go_bag.items_count} ready"
      elsif (to_buy = go_bag.to_buy_count(today)).positive?
        "#{to_buy} to buy"
      else
        "All ready"
      end
    end
end
