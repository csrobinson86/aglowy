require "test_helper"

class HouseholdTest < ActiveSupport::TestCase
  test "requires a name" do
    household = Household.new(name: "")

    assert_not household.valid?
    assert_includes household.errors[:name], "can't be blank"
  end

  test "rejects an unknown time zone" do
    household = Household.new(name: "The Lees", time_zone: "Mars/Olympus Mons")

    assert_not household.valid?
    assert_includes household.errors[:time_zone], "is not included in the list"
  end

  test "create_with_head creates the household and a head membership" do
    household = Household.create_with_head(household: { name: "The Newcomers" }, head: users(:newcomer))

    assert household.persisted?
    assert_equal [ [ users(:newcomer), "head" ] ], household.memberships.map { [ it.user, it.role ] }
  end

  test "create_with_head creates nothing when the head membership is invalid" do
    assert_no_difference [ "Household.count", "Membership.count" ] do
      assert_raises ActiveRecord::RecordInvalid do
        Household.create_with_head(household: { name: "The Nobodies" }, head: nil)
      end
    end
  end

  test "add_member creates a user with no identity and a membership with the given role" do
    membership = households(:home).add_member(name: "Baby Head", role: :child)

    assert membership.persisted?
    assert membership.child?
    assert_equal "Baby Head", membership.user.name
    assert_nil membership.user.identity
  end

  test "add_member with a blank name raises RecordInvalid and creates nothing" do
    assert_no_difference [ "User.count", "Membership.count" ] do
      assert_raises ActiveRecord::RecordInvalid do
        households(:home).add_member(name: " ", role: :child)
      end
    end
  end

  test "add_member refuses the head role" do
    assert_raises ArgumentError do
      households(:home).add_member(name: "Second Head", role: :head)
    end
  end

  test "storage_used sums only this household's files, in one query" do
    photo = direct_uploaded_blob("photo.png")
    family_study_sessions(:weekly_next).add_files([ photo.signed_id ])
    households(:other).schedule_family_study(starts_on: Date.current, time_of_day: "19:00", files: [ direct_uploaded_blob("study-guide.pdf") ])
    use_home_storage(1.gigabyte)

    household = households(:home)

    assert_queries_count(1) { assert_equal 1.gigabyte + photo.byte_size, household.storage_used }
    assert_equal file_fixture("study-guide.pdf").size, households(:other).storage_used
  end

  test "links count zero" do
    households(:parents).schedule_family_study(starts_on: Date.current, time_of_day: "19:00", links: [ "https://www.jw.org/en/" ])

    assert_equal 0, households(:parents).storage_used
  end

  test "the quota is 2 GB" do
    assert_equal 2.gigabytes, households(:home).storage_quota
  end

  test "storage is nearly full from 80% of the quota" do
    household = households(:home)

    use_home_storage((household.storage_quota * 0.8).ceil - 1)
    assert_not household.storage_nearly_full?

    use_home_storage((household.storage_quota * 0.8).ceil)
    assert household.storage_nearly_full?
    assert_not household.storage_full?
    assert_equal 80, household.storage_percent_used
  end

  test "storage is full at 100% of the quota" do
    household = households(:home)

    use_home_storage(household.storage_quota - 1)
    assert_not household.storage_full?
    assert household.fits_in_storage?(1)
    assert_not household.fits_in_storage?(2)

    use_home_storage(household.storage_quota)
    assert household.storage_full?
    assert_equal 100, household.storage_percent_used
  end

  test "database: a household without a name raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      Household.insert!({ name: nil })
    end
  end
end
