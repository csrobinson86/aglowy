# "What you get" (frames settings-notifications.png and settings-notifications-child.png): a check box group per kind
# the person can get, named for the kind, saying what it is, with an Email box that says when its email goes. Someone
# who can't get email, a child or a username-only login, gets no Email box, and then there's nothing to save. The
# mockup's table is drawn as groups, and its Phone column comes with push.
class Settings::NotificationsForm < ApplicationForm
  def initialize(user:)
    @user = user
  end

  form do |f|
    chosen = @user.notification_settings.pluck(:kind, :channel)

    @user.notification_kinds.each do |kind|
      f.check_box_group(name: kind.name, label: kind.label, caption: kind.description) do |group|
        group.check_box(value: "email", label: "Email", caption: kind.email_caption, checked: [ kind.name, "email" ].in?(chosen)) if @user.emailable?
      end
    end

    f.submit(name: :submit, label: "Save") if @user.emailable?
  end
end
