require "test_helper"

class FamilyStudiesControllerTest < ActionDispatch::IntegrationTest
  test "a member sees upcoming sessions in order" do
    sign_in identities(:spouse)

    get household_family_studies_path(household_id: households(:home))

    assert_response :success
    assert_select "title", "Family studies · The Head Family · Aglowy"
    assert_select "h1", "Family studies"
    assert_select "#coming-up .Box-header h2", "Coming up"
    assert_select "#coming-up .Box-row", count: 4
    assert_select "main", text: /Topic not chosen yet.*Draw Close to Jehovah, chapter 1.*Topic not chosen yet/m
    assert_select "#coming-up .Box-row .color-fg-muted", text: "Topic not chosen yet"
    assert_select "#coming-up .Box-row .Label", text: "Once", count: 1
    assert_select "#coming-up .Box-row .Label", text: "Weekly", count: 3
    assert_not_includes response.body, "Lessons From the Life of Ruth", "a past session isn't coming up"
  end

  test "cancelled ones marked" do
    sign_in identities(:spouse)

    get household_family_studies_path(household_id: households(:home))

    assert_select "#coming-up .Box-row", text: /Cancelled/, count: 1
    assert_select "#coming-up .Box-row:nth-of-type(3) s"
    assert_select "#coming-up .Box-row:nth-of-type(3) .Label", text: "Cancelled"
    assert_select "#coming-up .Box-row:not(:nth-of-type(3)) s", count: 0
  end

  test "each row links to its session" do
    sign_in identities(:spouse)

    get household_family_studies_path(household_id: households(:home))

    family_study_sessions(:one_off_first, :weekly_next, :weekly_cancelled, :weekly_later).each do |study_session|
      path = household_family_study_session_path(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)
      assert_select "#coming-up .Box-row a[href='#{path}']", count: 1
    end
    assert_select "#coming-up .Box-row a", text: /Draw Close to Jehovah, chapter 1/
  end

  test "another household's studies aren't shown" do
    study = households(:other).schedule_family_study(topic: "The Outsiders' study", frequency: :once, starts_on: 2.days.from_now.to_date, time_of_day: "18:00")
    assert study.persisted?
    sign_in identities(:head)

    get household_family_studies_path(household_id: households(:home))

    assert_select "#coming-up .Box-row", count: 4
    assert_select "main", text: /The Outsiders' study/, count: 0
  end

  test "a non-member gets 404" do
    sign_in identities(:outsider)

    get household_family_studies_path(household_id: households(:home))

    assert_response :not_found
  end

  test "times show in the household's zone, not the server's" do
    households(:home).update!(time_zone: "Tokyo")
    sign_in identities(:head)

    get household_family_studies_path(household_id: households(:home))

    # Every fixture session is 19:00 UTC, which is 4:00 the next morning in Tokyo.
    assert_select "#coming-up .Box-row", text: /4:00 AM/, count: 4
    assert_select ".family-studies-next", text: /4:00 AM/
    assert_select ".family-study-row", text: /4:00 AM/, count: 3
    assert_not_includes response.body, "7:00 PM"
  end

  test "shows only the next 10 sessions" do
    family_studies(:weekly).extend_sessions
    sign_in identities(:head)

    get household_family_studies_path(household_id: households(:home))

    assert_select "#coming-up .Box-row", count: 10
    # On a phone, the Next card and the other nine.
    assert_select ".family-studies-next", count: 1
    assert_select ".family-study-row", count: 9
  end

  test "with no sessions, heads and adults are told to schedule the first study" do
    households(:home).family_studies.destroy_all

    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity

      get household_family_studies_path(household_id: households(:home))

      assert_select ".blankslate h2", "No family studies yet"
      assert_select ".blankslate", text: /Schedule your family's first study\./
      assert_select ".Box-row", count: 0
    end
  end

  test "with no sessions, a child is told a parent will schedule one" do
    households(:home).family_studies.destroy_all
    sign_in child_identity

    get household_family_studies_path(household_id: households(:home))

    assert_select ".blankslate h2", "No family studies yet"
    assert_select ".blankslate", text: /When a parent schedules a family study, it will show up here\./
    assert_select ".blankslate", text: /Schedule your family's first study/, count: 0
  end

  test "a head and an adult can create" do
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity

      assert_difference -> { households(:home).family_studies.count } => 1 do
        post household_family_studies_path(household_id: households(:home)), params: { family_study_scheduling: valid_params }
      end

      assert_redirected_to household_family_studies_path(household_id: households(:home))
      assert_equal "Your family study is scheduled.", flash[:notice]
    end
  end

  test "uploaded files from the drop zone go on the first session" do
    sign_in identities(:head)

    post household_family_studies_path(household_id: households(:home)),
         params: { family_study_scheduling: valid_params.merge(files: [ direct_uploaded_blob("study-guide.pdf").signed_id ]) }

    resource = households(:home).family_study_resources.file.where.not(id: family_study_resources(:study_guide)).sole
    assert_equal "study-guide.pdf", resource.title
  end

  test "a refused file re-renders the form with its error by the drop zone, keeping the good one" do
    sign_in identities(:head)
    pdf = direct_uploaded_blob("study-guide.pdf")

    post household_family_studies_path(household_id: households(:home)),
         params: { family_study_scheduling: valid_params.merge(files: [ pdf.signed_id, direct_uploaded_blob("program.exe", filename: "notes.pdf").signed_id ]) }

    assert_response :unprocessable_content
    assert_select ".FormControl-inlineValidation", text: /notes.pdf must be a PDF or an image/
    assert_select "input[type=hidden][name='family_study_scheduling[files][]'][value='#{pdf.signed_id}']"
    assert_select "li", text: /study-guide.pdf/
  end

  test "a head and an adult see the form and the Schedule a study buttons" do
    households(:home).family_studies.destroy_all

    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity

      get new_household_family_study_path(household_id: households(:home))
      assert_response :success
      assert_select "title", "Schedule a family study · The Head Family · Aglowy"
      assert_select "h1", "Schedule a family study"
      assert_select "nav[aria-label='Breadcrumb'] a", text: "Family studies"
      assert_select "form[action='#{household_family_studies_path(household_id: households(:home))}']"
      assert_select "main a[href='#{household_family_studies_path(household_id: households(:home))}']", "Cancel"

      get household_family_studies_path(household_id: households(:home))
      assert_select ".Subhead a[href='#{new_household_family_study_path(household_id: households(:home))}']" do
        assert_select ".d-md-none", "New"
        assert_select ".d-none.d-md-inline", "Schedule a study"
      end
      assert_select ".blankslate a[href='#{new_household_family_study_path(household_id: households(:home))}']", "Schedule a study"
    end
  end

  test "a child gets refused and sees no Schedule button" do
    sign_in child_identity

    get new_household_family_study_path(household_id: households(:home))
    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]

    assert_no_difference [ "FamilyStudy.count", "FamilyStudy::Session.count" ] do
      post household_family_studies_path(household_id: households(:home)), params: { family_study_scheduling: valid_params }
    end
    assert_redirected_to household_root_path(household_id: households(:home))

    get household_family_studies_path(household_id: households(:home))
    assert_select "a", { text: "Schedule a study", count: 0 }

    households(:home).family_studies.destroy_all
    get household_family_studies_path(household_id: households(:home))
    assert_select "a", { text: "Schedule a study", count: 0 }
  end

  test "invalid input re-renders with errors" do
    sign_in identities(:head)

    assert_no_difference [ "FamilyStudy.count", "FamilyStudy::Session.count" ] do
      post household_family_studies_path(household_id: households(:home)),
           params: { family_study_scheduling: valid_params.merge(topic: "Proverbs 3", ends_at: "18:00", notes: "<p>Questions to discuss</p>") }
    end

    assert_response :unprocessable_content
    assert_select ".FormControl-inlineValidation", text: /must be after Starts\. Studies that end after midnight aren't supported\./
    assert_select "input[name='family_study_scheduling[topic]'][value='Proverbs 3']"
    assert_select "input[name='family_study_scheduling[starts_at]'][value='19:00']"
    assert_select "option[value='weekly'][selected]"
    assert_select "lexxy-editor[name='family_study_scheduling[notes]'][value='<p>Questions to discuss</p>']"
  end

  test "the Schedule a study notes take scripture links, and the first session keeps them" do
    ruth = Bible::Reference.find("8:1:16")
    sign_in identities(:head)

    get new_household_family_study_path(household_id: households(:home))
    assert_select "lexxy-editor[name='family_study_scheduling[notes]'][permitted-attachment-types='application/vnd.actiontext.scripture'][remote-images=false][data-controller=no-uploads]"

    post household_family_studies_path(household_id: households(:home)),
         params: { family_study_scheduling: valid_params.merge(topic: "Loyal love", notes: "<p>#{scripture_attachment(ruth.id)}</p>") }

    assert_redirected_to household_family_studies_path(household_id: households(:home))
    assert_equal [ ruth ], FamilyStudy::Session.find_by!(topic: "Loyal love").notes.body.attachables
  end

  test "a typed matt 24:14 in the Schedule a study notes is linked on the first session, in its paragraph" do
    sign_in identities(:head)

    post household_family_studies_path(household_id: households(:home)),
         params: { family_study_scheduling: valid_params.merge(topic: "Keep on the watch", notes: "<p>Read matt 24:14 tonight</p>") }

    assert_redirected_to household_family_studies_path(household_id: households(:home))
    notes = FamilyStudy::Session.find_by!(topic: "Keep on the watch").notes.body
    assert_equal [ Bible::Reference.find("40:24:14") ], notes.attachables
    assert_equal "Read Matthew 24:14 tonight", notes.to_plain_text
    assert_equal 1, notes.fragment.find_all("p").size
  end

  test "the Schedule a study form shows again with the notes as typed, to be linked on the next save" do
    sign_in identities(:head)

    post household_family_studies_path(household_id: households(:home)),
         params: { family_study_scheduling: valid_params.merge(ends_at: "18:00", notes: "<p>Read matt 24:14</p>") }

    assert_response :unprocessable_content
    assert_select "lexxy-editor[name='family_study_scheduling[notes]'][value='<p>Read matt 24:14</p>']"
  end

  test "the Repeat choices follow the date in the query" do
    sign_in identities(:head)

    get new_household_family_study_path(household_id: households(:home)), params: { family_study_scheduling: { starts_on: "2026-11-24" } }

    assert_select "turbo-frame#family_study_scheduling_repeat select option", text: "Monthly on the last Tuesday"
    assert_select "turbo-frame#family_study_scheduling_repeat select option", text: "Monthly on the fourth Tuesday"
  end

  test "a malformed date query still shows the form" do
    sign_in identities(:head)

    get new_household_family_study_path(household_id: households(:home)), params: { family_study_scheduling: "x" }

    assert_response :success
  end

  test "a non-member gets 404 for the form and for creating" do
    sign_in identities(:outsider)

    get new_household_family_study_path(household_id: households(:home))
    assert_response :not_found

    # The 404 response doesn't carry the session cookie, so sign in again.
    sign_in identities(:outsider)
    assert_no_difference "FamilyStudy.count" do
      post household_family_studies_path(household_id: households(:home)), params: { family_study_scheduling: valid_params }
    end
    assert_response :not_found
  end

  test "new with a step prefills the topic" do
    step = goal_steps(:read_luke)
    sign_in identities(:spouse)

    get new_household_family_study_path(household_id: households(:home), goal_step_id: step.id)

    assert_response :success
    assert_select "input[name='family_study_scheduling[topic]'][value='Read Luke together']"
    assert_select "input[name='family_study_scheduling[starts_on]'][value='2027-02-15']"
    assert_select "input[type=hidden][name='family_study_scheduling[goal_step_id]'][value='#{step.id}']"
    assert_select "main a[href='#{household_goal_path(household_id: households(:home), id: goals(:gospels))}']", "Cancel"
  end

  test "new without a step carries no step" do
    sign_in identities(:spouse)

    get new_household_family_study_path(household_id: households(:home))

    assert_select "input[name='family_study_scheduling[goal_step_id]']", count: 0
  end

  # Create family study (docs/design/personal-study.md): the AI panel opens on Describe, nothing sent yet.
  test "from_study prefills the Describe box for the owner" do
    study = personal_studies(:head_suffering)
    personal_study_question(study, prompt: "What did Job learn?")
    personal_study_question(study, prompt: "How does the ransom fit in?")
    users(:head).accept_ai_terms(understood: true)
    sign_in identities(:head)

    assert_no_difference -> { FamilyStudy::Draft.count } do
      get new_household_family_study_path(household_id: households(:home), from_study: study.id)
    end

    assert_response :success
    assert_select "[data-ai-panel-target=opened]:not([hidden])"
    assert_select "textarea[name='family_study_draft[prompt]']", text: "Why does Jehovah allow suffering?: How does the ransom fit in?"
  end

  test "from_study is ignored for someone else's study" do
    personal_study_question(personal_studies(:spouse_ransom), prompt: "Why was a ransom needed?")
    users(:head).accept_ai_terms(understood: true)
    sign_in identities(:head)

    get new_household_family_study_path(household_id: households(:home), from_study: personal_studies(:spouse_ransom).id)

    assert_response :success
    assert_select "[data-ai-panel-target=opened][hidden]"
    assert_select "textarea[name='family_study_draft[prompt]']", text: ""
    assert_not_includes response.body, "The ransom"
    assert_not_includes response.body, "Why was a ransom needed?"
  end

  test "scheduling from a step links it and goes back to the goal" do
    step = goal_steps(:read_luke)
    sign_in identities(:spouse)

    assert_difference "FamilyStudy.count" => 1 do
      post household_family_studies_path(household_id: households(:home)), params: { family_study_scheduling: valid_params.merge(goal_step_id: step.id) }
    end

    assert_redirected_to household_goal_path(household_id: households(:home), id: goals(:gospels))
    assert_equal "The study is scheduled and linked to this step.", flash[:notice]
    assert_equal households(:home).family_studies.order(:created_at).last, step.reload.family_study
  end

  test "a step that's already scheduled re-renders the form saying so" do
    step = goal_steps(:read_luke)
    step.update_column(:family_study_id, family_studies(:weekly).id)
    sign_in identities(:spouse)

    assert_no_difference "FamilyStudy.count" do
      post household_family_studies_path(household_id: households(:home)), params: { family_study_scheduling: valid_params.merge(goal_step_id: step.id) }
    end

    assert_response :unprocessable_content
    assert_select ".flash-error", text: "That step is already scheduled as a family study"
  end

  test "a step from another household is 404" do
    sign_in identities(:head)

    get new_household_family_study_path(household_id: households(:home), goal_step_id: goal_steps(:read_acts).id)
    assert_response :not_found

    sign_in identities(:head)
    assert_no_difference "FamilyStudy.count" do
      post household_family_studies_path(household_id: households(:home)), params: { family_study_scheduling: valid_params.merge(goal_step_id: goal_steps(:read_acts).id) }
    end
    assert_response :not_found
    assert_nil goal_steps(:read_acts).reload.family_study_id
  end

  test "a step of a finished goal is refused" do
    goals(:gospels).complete(by: users(:spouse))
    sign_in identities(:spouse)

    get new_household_family_study_path(household_id: households(:home), goal_step_id: goal_steps(:read_luke).id)

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
  end

  test "a child is refused scheduling a step (as today)" do
    sign_in child_identity

    get new_household_family_study_path(household_id: households(:home), goal_step_id: goal_steps(:read_luke).id)
    assert_redirected_to household_root_path(household_id: households(:home))

    assert_no_difference "FamilyStudy.count" do
      post household_family_studies_path(household_id: households(:home)), params: { family_study_scheduling: valid_params.merge(goal_step_id: goal_steps(:read_luke).id) }
    end
    assert_redirected_to household_root_path(household_id: households(:home))
    assert_nil goal_steps(:read_luke).reload.family_study_id
  end

  private
    def valid_params
      { topic: "", starts_on: 3.days.from_now.to_date.iso8601, starts_at: "19:00", ends_at: "19:45", repeat: "weekly" }
    end

    # Charlie Child has no login in the fixtures, so give them one here.
    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
