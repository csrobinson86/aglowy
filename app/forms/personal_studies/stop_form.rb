# "Stop" on a question while it's answered (docs/design/personal-study.md, Pages and routes: Stop).
class PersonalStudies::StopForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Stop", size: :small)
  end
end
