# A person's photo, at one URL used on every page (docs/design/avatars.md, Serving the image). The browser keeps it but
# asks every time, so the visibility check runs on every use: someone who leaves the household stops seeing it, and an
# unchanged photo costs a 304 with no body. Not finding and not seeing look the same (Traps 4).
class AvatarsController < ApplicationController
  def show
    user = User.find(params[:user_id])
    authorize user, :show_avatar?, policy_class: AvatarPolicy
    raise ActiveRecord::RecordNotFound unless user.avatar.attached?

    # Not no_cache, which drops private; never no-store, which stops the browser keeping it.
    response.cache_control.merge!(private: true, max_age: 0, must_revalidate: true)
    if stale?(user.avatar.blob, public: false)
      send_data user.avatar.download, type: "image/webp", disposition: "inline"
    end
  end

  private
    def not_authorized
      raise ActiveRecord::RecordNotFound
    end
end
