# A person's own studies. They're the same in every household the person belongs to, so they're reached through
# Current.user, never Current.household or an id alone (docs/design/personal-study.md, Pages and routes).
# A collection id from the form is looked up through Current.user.collections, so another person's is a 404.
class PersonalStudiesController < ApplicationController
  include HouseholdScoped
  include TagFiltered

  before_action :set_personal_study, only: %i[ show update destroy ]

  # ?collection= and ?tag= narrow the list, and ?q= searches titles, collection names and tag names. A collection
  # that isn't one of the person's for studies, like an unknown tag, filters the list to nothing.
  def index
    authorize PersonalStudy
    @collections = Current.user.collections.for_studies.with_personal_studies_count.positioned
    @tags = Current.user.tags.with_taggings_count.order(:name)
    @query = params[:q].to_s.squish.presence
    @collection_id = params[:collection].presence
    @collection = @collections.find { it.id == @collection_id } if @collection_id
    @personal_studies = tagged(filtered(Current.user.personal_studies)).preloaded.recent_first
    @total_count = Current.user.personal_studies.count
  end

  def new
    @personal_study = Current.user.personal_studies.new(collection: Current.user.collections.for_studies.find_by(id: params[:collection]))
    authorize @personal_study
  end

  def create
    @personal_study = Current.user.personal_studies.new(study_attributes(:title, :collection_id))
    @first_question = params.fetch(:personal_study, {}).permit(:prompt)[:prompt]
    authorize @personal_study

    if @personal_study.save
      ask_first_question
      redirect_to household_personal_study_path(id: @personal_study), notice: "Study started."
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
  end

  # Rename and move come here; anything refused shows the page again with the reason.
  def update
    if @personal_study.update(study_attributes(:title, :collection_id))
      redirect_to household_personal_study_path(id: @personal_study), notice: "Study saved."
    else
      render :show, status: :unprocessable_content
    end
  end

  # Under the study's lock, taken before the note's as Save to note takes them, so the two can't deadlock.
  def destroy
    @personal_study.with_lock { @personal_study.destroy! }
    redirect_to household_personal_studies_path, notice: "Study deleted."
  end

  private

  # With whether each answer is in the study's note, for its card's Save to note when the page is shown.
  def set_personal_study
    @personal_study = Current.user.personal_studies.preloaded.includes(questions: :note_saving).find(params[:id])
    authorize @personal_study
  end

  # A first question from the New study page is asked straight away (docs/design/personal-study.md, Pages and routes:
  # New study). One refused (the day's limit, say) leaves the study started, with the reason.
  def ask_first_question
    return if @first_question.blank?

    question = @personal_study.ask(@first_question, by: Current.user, young_reader: Current.membership.child?)
    flash[:alert] = question.errors.full_messages.to_sentence unless question.persisted?
  end

  def filtered(studies)
    studies = @collection ? studies.where(collection: @collection) : studies.none if @collection_id
    @query ? studies.matching(@query) : studies
  end

  # A blank collection_id takes the study out of any collection.
  def study_attributes(*permitted)
    attributes = params.expect(personal_study: permitted).to_h
    if attributes.key?(:collection_id)
      collection_id = attributes.delete(:collection_id)
      attributes[:collection] = collection_id.presence && Current.user.collections.find(collection_id)
    end
    attributes
  end
end
