# Remove step, the answer to the question a step's panel asks before removing it (docs/design/phone.md, A goal).
class Goals::Steps::RemovalForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Remove step", scheme: :danger, block: true)
  end
end
