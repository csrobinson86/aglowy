# The suggested categories and items for a new bag, and the guide's title and link, read from
# config/go_bag_suggestions.yml (docs/design/go-bags.md, GoBag::Suggestions). Aglowy's own list: only the guide's title
# and link come from jw.org.
class GoBag::Suggestions
  PATH = Rails.root.join("config/go_bag_suggestions.yml")

  Guide = Data.define(:title, :publication, :url)
  Category = Data.define(:key, :name, :items)
  Item = Data.define(:name, :quantity)

  def guide
    Guide.new(**data.fetch("guide").symbolize_keys)
  end

  def categories
    data.fetch("categories").map do |category|
      Category.new(key: category.fetch("key"), name: category.fetch("name"),
                   items: category.fetch("items").map { Item.new(name: it.fetch("name"), quantity: it["quantity"]) })
    end
  end

  private
    def data
      @data ||= YAML.load_file(PATH, freeze: true)
    end
end
