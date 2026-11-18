# Adding, editing and deleting a focus area of the person's plan, in a dialog loaded into Your plan's Turbo Frame
# (docs/design/daily-brief.md, Your plan). Found through Current.user's own plan, so someone else's is a 404. A refused
# save shows the dialog again with the reasons; a saved one closes it and redraws the plan's focus areas and week.
class DailyBriefs::Plans::FocusAreasController < ApplicationController
  include HouseholdScoped

  before_action { authorize :daily_brief }
  before_action :set_plan
  before_action :set_focus_area, only: %i[ edit update destroy ]

  # Blank, or filled in from a library entry the plan can still take (from=ministry). One it can't, a second quality
  # say, is a blank one.
  def new
    entry = @plan.library_offers.find { it.key == params[:from] }
    @focus_area = @plan.focus_areas.new(entry&.attributes || { kind: "role" })
  end

  def create
    @focus_area = @plan.add_focus_area(params.expect(daily_brief_focus_area: %i[ kind name gives scriptures ]))

    if @focus_area.persisted?
      close_dialog "Focus area added.", focus: @focus_area
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  # The kind is set when it's added and never changes.
  def update
    if @focus_area.update(params.expect(daily_brief_focus_area: %i[ name gives scriptures ]))
      close_dialog "Focus area saved.", focus: @focus_area
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Its topics come off the week with it.
  def destroy
    @focus_area.destroy!
    close_dialog "Focus area deleted.", focus: :add
  end

  private
    def set_plan
      @plan = DailyBrief::Plan.find_by!(user: Current.user)
    end

    def set_focus_area
      @focus_area = @plan.focus_areas.find(params[:id])
    end

    # Empties the dialog's frame, which closes it, and redraws the focus areas and the week with the notice, from the plan
    # as it now is, with focus on the control the focus areas list names (focus:). Without Turbo, back to the plan.
    def close_dialog(notice, focus:)
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = notice
          @focus = focus
          @plan.reload
          render :saved
        end
        format.html { redirect_to household_daily_brief_plan_path, notice:, status: :see_other }
      end
    end
end
