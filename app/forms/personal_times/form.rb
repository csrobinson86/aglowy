# The "my time" dialog (docs/design/calendar.md, The "my time" dialog), a section at a time so the dialog can put the
# meeting prep line between them. Days are a check box group laid out in a row; the empty wdays[] lets none ticked
# clear them, so the save is refused rather than keeping the old days.
class PersonalTimes::Form < ApplicationForm
  DAYS = { 1 => "Mon", 2 => "Tue", 3 => "Wed", 4 => "Thu", 5 => "Fri", 6 => "Sat", 0 => "Sun" }.freeze

  # section: :when, :opens or :actions. :opens needs user, for their studies and notes; :actions needs dialog_id, for Cancel.
  def initialize(section:, user: nil, dialog_id: nil)
    @section = section
    @user = user
    @dialog_id = dialog_id
  end

  form do |f|
    time = f.builder.object

    case @section
    when :when
      f.hidden(name: :zone_shown)
      f.radio_button_group(name: :kind, label: "What for") do |group|
        PersonalTime::KINDS.each { |value, label| group.radio_button(value:, label:, data: { action: "personal-time#kindChanged" }) }
      end
      f.text_field(name: :title, label: "Title", required: true, maxlength: 80, full_width: true, data: { personal_time_target: "title" })
      f.hidden(name: :wdays, value: "", multiple: true, id: "personal_time_wdays_sent")
      f.check_box_group(name: :wdays, label: "Days", classes: "personal-time-days") do |group|
        DAYS.each { |wday, label| group.check_box(value: wday, label:, checked: time.wdays.include?(wday)) }
      end
      f.group(layout: :horizontal) do |row|
        row.text_field(name: :time_of_day, label: "At", type: :time, required: true, value: time.time_of_day&.strftime("%H:%M"))
        row.select_list(name: :duration_minutes, label: "For") do |list|
          PersonalTime::DURATIONS.each { |minutes, label| list.option(label:, value: minutes) }
        end
      end
    when :opens
      f.select_list(name: :opens_key, label: "Opens", full_width: true, caption: "One of your personal studies or notes.") do |list|
        list.option(label: "Nothing", value: "")
        @user.personal_studies.order(:title).each { list.option(label: "Study: #{it.title}", value: "PersonalStudy/#{it.id}") }
        @user.personal_notes.order(:title).each { list.option(label: "Note: #{it.title}", value: "PersonalNote/#{it.id}") }
      end
    when :actions
      f.group(layout: :horizontal, justify_content: :flex_end) do |actions|
        actions.button(name: :cancel, label: "Cancel", data: { close_dialog_id: @dialog_id })
        actions.submit(name: :submit, label: time.new_record? ? "Add time" : "Save time", scheme: :primary)
      end
    end
  end
end
