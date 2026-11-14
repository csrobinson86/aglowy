require "test_helper"

class FamilyStudiesControllerTest < ActionDispatch::IntegrationTest
  test "a member sees upcoming sessions in order" do
    sign_in identities(:spouse)

    get household_family_studies_path(household_id: households(:home))

    assert_response :success
    assert_select "title", "Family studies · The Head Family · Aglowy"
    assert_select "h1", "Family studies"
    assert_select "main .Box-header h2", "Coming up"
    assert_select "main .Box-row", count: 4
    assert_select "main", text: /Topic not chosen yet.*Draw Close to Jehovah, chapter 1.*Topic not chosen yet/m
    assert_select "main .Box-row .color-fg-muted", text: "Topic not chosen yet"
    assert_select "main .Box-row .Label", text: "Once", count: 1
    assert_select "main .Box-row .Label", text: "Weekly", count: 3
    assert_not_includes response.body, "Lessons From the Life of Ruth", "a past session isn't coming up"
  end

  test "cancelled ones marked" do
    sign_in identities(:spouse)

    get household_family_studies_path(household_id: households(:home))

    assert_select "main .Box-row", text: /Cancelled/, count: 1
    assert_select "main .Box-row:nth-of-type(3) s"
    assert_select "main .Box-row:nth-of-type(3) .Label", text: "Cancelled"
    assert_select "main .Box-row:not(:nth-of-type(3)) s", count: 0
  end

  test "another household's studies aren't shown" do
    study = households(:other).schedule_family_study(topic: "The Outsiders' study", frequency: :once, starts_on: 2.days.from_now.to_date, time_of_day: "18:00")
    assert study.persisted?
    sign_in identities(:head)

    get household_family_studies_path(household_id: households(:home))

    assert_select "main .Box-row", count: 4
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
    assert_select "main .Box-row", text: /4:00 AM/, count: 4
    assert_not_includes response.body, "7:00 PM"
  end

  test "shows only the next 10 sessions" do
    family_studies(:weekly).extend_sessions
    sign_in identities(:head)

    get household_family_studies_path(household_id: households(:home))

    assert_select "main .Box-row", count: 10
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
    sign_in Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)

    get household_family_studies_path(household_id: households(:home))

    assert_select ".blankslate h2", "No family studies yet"
    assert_select ".blankslate", text: /When a parent schedules a family study, it will show up here\./
    assert_select ".blankslate", text: /Schedule your family's first study/, count: 0
  end
end
