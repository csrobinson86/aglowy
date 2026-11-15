class Sessions::SignOutForm < ApplicationForm
  # Small in the sidebar and header; full size where it's the page's only action.
  def initialize(size: :small)
    @size = size
  end

  form do |f|
    f.submit(name: :sign_out, label: "Sign out", size: @size)
  end
end
