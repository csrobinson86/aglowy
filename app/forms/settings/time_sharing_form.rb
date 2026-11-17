# Share my times (frame settings-calendar.png): a check box per active household the person is in, ticked where they
# share, then Save. The empty household_ids[] says the form was sent even with nothing ticked.
class Settings::TimeSharingForm < ApplicationForm
  def initialize(memberships:)
    @memberships = memberships
  end

  form do |f|
    f.hidden(name: :household_ids, value: "", multiple: true, id: "time_sharing_household_ids_sent")
    f.check_box_group(name: :household_ids, label: "Share my times with", visually_hide_label: true) do |group|
      @memberships.each { group.check_box(value: it.household_id, label: it.household.name, checked: it.shares_times?) }
    end

    f.submit(name: :submit, label: "Save")
  end
end
