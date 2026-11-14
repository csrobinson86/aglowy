# One page of a list, a fixed number of records at a time. Loads one record more than it shows, to know whether
# there's a next page. The page number is capped so a huge one in the URL can't overflow the offset.
class Page
  SIZE = 20
  LAST = 10_000

  attr_reader :number

  def initialize(relation, number:)
    @relation = relation
    @number = number.to_i.clamp(1, LAST)
  end

  def records
    loaded.first(SIZE)
  end

  def previous?
    number > 1
  end

  def next?
    loaded.size > SIZE
  end

  private
    def loaded
      @loaded ||= @relation.offset((number - 1) * SIZE).limit(SIZE + 1).to_a
    end
end
