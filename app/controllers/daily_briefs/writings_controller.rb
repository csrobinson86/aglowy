# Another angle, Try again and Write it with AI, the progress while a writing runs, and Stop (docs/design/daily-brief.md,
# How a writing runs; The brief, its states). Today's brief and the writings are found through Current.user, so anyone
# else's is a 404. brief.write decides everything else under the person's lock, and a refusal is said in words.
class DailyBriefs::WritingsController < ApplicationController
  include HouseholdScoped

  before_action { authorize :daily_brief }
  before_action :no_store # Personal, like the brief's page.
  before_action :set_writing, only: %i[ show destroy ]

  # "Write it with AI" passes first, so a brief that has a writing already isn't written again.
  def create
    brief = Current.user.daily_briefs.find_by!(on: Current.user.today)
    writing = brief.write(by: Current.user, first: params[:first] == "true")

    redirect_to household_daily_brief_path, alert: (writing.errors.full_messages.to_sentence + "." if writing.errors.any?), status: :see_other
  end

  # The progress, for its Turbo Frame. As a Turbo Stream it's asked for each time the page subscribes to the writing's
  # stream: an ending that came before then was broadcast to nobody, so the page is refreshed from here.
  def show
    respond_to do |format|
      format.html { render partial: "daily_briefs/writings/progress", locals: { writing: @writing } }
      format.turbo_stream { @writing.writing? ? head(:no_content) : render(turbo_stream: turbo_stream.refresh(request_id: nil)) }
    end
  end

  # Stop. Never deletes the writing, so it keeps its use and still counts; one that has finished is left as it is.
  def destroy
    @writing.stop
    redirect_to household_daily_brief_path, status: :see_other
  end

  private
    def set_writing
      @writing = Current.user.daily_brief_writings.find(params[:id])
    end
end
