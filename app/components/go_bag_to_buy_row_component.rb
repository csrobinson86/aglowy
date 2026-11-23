# frozen_string_literal: true

# One thing on To buy (docs/design/go-bags.md, To buy; frame go-bags-to-buy.png). A thing to get has the "we have it"
# box, as on a bag's page, and how many. A thing to replace has a clock, "Use by Dec 20 · replace it" in the attention
# color ("Expired Nov 20 · replace it" in the danger color once it has passed), and "›" opening the item's page to set
# the new date. A tick redraws the row with its box (box: true), ticked or not, so a thing just ticked stays on the list
# until the page is reloaded, and a mis-tap can be unticked.
class GoBagToBuyRowComponent < GoBagItemRowComponent
  def initialize(item:, today:, box: item.to_get?, focus: false)
    super(item:, today:, focus:)
    @box = box
  end

  def box?
    @box
  end

  # How many, for a thing to get; when to replace it, for a thing to replace.
  def line
    if box?
      Part.new(item.quantity, nil) if item.quantity.present?
    elsif item.expired?(today)
      Part.new("Expired #{short_date(item.use_by)} · replace it", :danger)
    else
      Part.new("Use by #{short_date(item.use_by)} · replace it", :attention)
    end
  end

  private
    # The tick's answer redraws this row, on To buy, rather than a bag page's row, ready box and tabs.
    def tick_params
      { from: "to_buy" }
    end
end
