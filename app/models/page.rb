# One page of a list, a fixed number of records at a time: 20, unless the list asks for another size. Loads one record
# more than it shows, to know whether there's a next page. The page number is capped so a huge one in the URL can't overflow the offset.
class Page
  SIZE = 20
  LAST = 10_000

  attr_reader :number, :size

  def initialize(relation, number:, size: SIZE)
    @relation = relation
    @number = number.to_i.clamp(1, LAST)
    @size = size
  end

  def records
    loaded.first(size)
  end

  def previous?
    number > 1
  end

  def next?
    loaded.size > size
  end

  private
    def loaded
      @loaded ||= @relation.offset((number - 1) * size).limit(size + 1).to_a
    end
end
