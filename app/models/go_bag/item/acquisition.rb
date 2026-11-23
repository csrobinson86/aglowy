# "We have it" for one item, and who ticked it. Only made through GoBag::Item#acquire; #unacquire deletes it.
class GoBag::Item::Acquisition < ApplicationRecord
  belongs_to :item, class_name: "GoBag::Item", inverse_of: :acquisition
  belongs_to :acquired_by, class_name: "User"
end
