# Settings → You → Study guide: a head or adult turns their own weekly study guide on or off (docs/design/study-guide.md,
# The Settings section). It saves the person, never Current.membership (docs/design/settings.md, Traps). Someone who is a
# child in every household has no such section, so it's a 404 for them like any page that isn't theirs.
class Settings::StudyGuidesController < ApplicationController
  include HouseholdScoped

  before_action { authorize @user = Current.user, :update? }
  before_action { raise ActiveRecord::RecordNotFound unless @user.may_have_study_guide? }

  def show
  end

  # Without accepted AI terms turning it on saves nothing, and the section shows again with its disabled box and the
  # line saying where to accept them.
  def update
    if !ticked?
      @user.turn_off_study_guide
      redirect_to household_settings_study_guide_path, notice: "Study guide turned off."
    elsif @user.turn_on_study_guide
      redirect_to household_settings_study_guide_path, notice: "Study guide turned on."
    else
      render :show, status: :unprocessable_content
    end
  end

  private
    # Where the line without accepted AI terms sends them to schedule a family study: this household, or for a child here
    # one where they're a head or an adult, since a child can't schedule one. The terms are the person's, so either counts.
    def family_study_household
      return Current.household unless Current.membership.child?

      @user.memberships.active.where(role: %w[ head adult ]).order(:created_at).first.household
    end
    helper_method :family_study_household

    # A check box sends "1", and its hidden field "0" when it's unticked.
    def ticked?
      params.expect(study_guide: [ :enabled ])[:enabled] == "1"
    end
end
