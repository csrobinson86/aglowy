# A person's own student parts. They're the same in every household the person belongs to, so they're reached through
# Current.user, never Current.household or an id alone: someone else's part is a 404 (docs/design/meeting-parts.md,
# Pages and routes). The one exception is reading: a part shared into this household is also found through
# MeetingPart.shared_with(Current.household), read-only and without its counsel. Adding and editing the details happen in a dialog loaded into the page's Turbo Frame; a part's page
# saves its preparation and counsel with the same update.
class MeetingPartsController < ApplicationController
  include HouseholdScoped

  before_action :set_meeting_part, only: %i[ edit update destroy ]

  def index
    authorize MeetingPart
    today = Current.user.today
    @coming_up = Current.user.meeting_parts.includes(:sharings).coming_up(today).load
    @earlier = Current.user.meeting_parts.includes(:sharings).earlier(today).load
    @shared_count = MeetingPart.shared_with(Current.household).count
  end

  # The date starts at this household's next midweek meeting, blank before its meeting times are set.
  def new
    @meeting_part = Current.user.meeting_parts.new(meeting_on: Current.household.next_midweek_meeting_on)
    authorize @meeting_part
  end

  def create
    @meeting_part = Current.user.meeting_parts.new(meeting_part_params)
    authorize @meeting_part

    if @meeting_part.save
      close_dialog "Part added.", refresh: true
    else
      render :new, status: :unprocessable_content
    end
  end

  # My own part first, else one shared into this household, else 404.
  def show
    @meeting_part = Current.user.meeting_parts.with_rich_text_preparation.find_by(id: params[:id]) ||
      MeetingPart.shared_with(Current.household).with_rich_text_preparation.includes(:user).find(params[:id])
    authorize @meeting_part
    set_draft
  end

  def edit
  end

  # References typed in the preparation are linked, as on every save. A refused save shows again what sent it: the
  # dialog, or the part's page. Saved details redraw only the part, so the preparation and counsel on the page behind the
  # dialog keep what's typed and not yet saved.
  def update
    @meeting_part.assign_attributes(meeting_part_params)
    @meeting_part.link_scriptures

    if @meeting_part.save
      close_dialog "Part saved.", refresh: !details_sent?
    else
      set_draft unless details_sent?
      render details_sent? ? :edit : :show, status: :unprocessable_content
    end
  end

  def destroy
    @meeting_part.destroy!
    redirect_to household_meeting_parts_path, notice: "Part deleted."
  end

  private
    def set_meeting_part
      @meeting_part = Current.user.meeting_parts.with_rich_text_preparation.find(params[:id])
      authorize @meeting_part
    end

    # The AI panel's current draft, so a reload or a refused save still shows the outline or Drafting.
    def set_draft
      @draft = @meeting_part.current_draft_for(Current.user) if policy(@meeting_part).draft?
    end

    def meeting_part_params
      params.expect(meeting_part: %i[ kind meeting_on minutes setting topic study_point assistant preparation counsel ])
    end

    # The dialog sends the part's details; the part's page sends only the preparation and the counsel.
    def details_sent?
      params[:meeting_part].key?(:kind)
    end

    # Empties the dialog's frame, which closes it, then refreshes the page behind it, which shows the notice, or redraws
    # the part and shows the notice in place. Without Turbo, it goes to the part.
    def close_dialog(notice, refresh:)
      respond_to do |format|
        format.turbo_stream do
          if refresh
            flash[:notice] = notice
            render :saved
          else
            flash.now[:notice] = notice
            render :details_saved
          end
        end
        format.html { redirect_to household_meeting_part_path(id: @meeting_part), notice:, status: :see_other }
      end
    end
end
