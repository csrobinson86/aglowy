class Members::MemberForm < ApplicationForm
  def initialize(role: nil)
    @role = role
  end

  form do |f|
    f.text_field(name: :name, label: "Name", required: true)

    f.select_list(name: :role, label: "Role", caption: "Members you add here don't get a login") do |list|
      Household::MEMBER_ROLES.each { |role| list.option(label: role.humanize, value: role, selected: role == @role) }
    end

    f.submit(name: :submit, label: "Add member", scheme: :primary)
  end
end
