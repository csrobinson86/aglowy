# "Remove bookmark" in a bookmark's Edit dialog. from: "list" refreshes the Bookmarks tab, as the row's button does.
class Bookmarks::RemoveForm < ApplicationForm
  form do |f|
    f.hidden(name: :from, value: "list", scope_name_to_model: false)
    f.submit(name: :submit, label: "Remove bookmark", scheme: :danger)
  end
end
