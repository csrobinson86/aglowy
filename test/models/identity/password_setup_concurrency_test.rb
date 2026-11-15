require "test_helper"

# Two submissions of one password link at the same moment: Identity::PasswordSetup#save takes identity.lock! and
# resolves the token again inside the transaction, so only one can set a password (docs/design/invitations.md,
# Child logins). Each thread needs its own committed view of the row, so this test runs outside a transaction.
class Identity::PasswordSetupConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @identity = identities(:eli)
    @original_password = @identity.encrypted_password
  end

  # Fixtures are committed in this test, so put Eli's password back for the tests that run after it.
  teardown do
    @identity.update_columns(encrypted_password: @original_password, failed_attempts: 0, locked_at: nil)
  end

  test "two threads submitting the same token together: exactly one succeeds and its password is stored" do
    token = @identity.generate_token_for(:password_setup)
    passwords = %w[ first-thread-pw second-thread-pw ]
    ready = Concurrent::CountDownLatch.new(passwords.size)
    go = Concurrent::CountDownLatch.new(1)

    threads = passwords.map do |password|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          setup = Identity::PasswordSetup.new(token: token, password: password, password_confirmation: password)
          setup.identity # Both resolve the token before either saves.
          ready.count_down
          go.wait
          [ password, setup.save ]
        end
      ensure
        ready.count_down # A thread that raised first still releases ready.wait; threads.map(&:value) re-raises.
      end
    end

    ready.wait
    go.count_down
    results = threads.map(&:value).to_h

    assert_equal [ false, true ], results.values.sort_by { it ? 1 : 0 }
    winner = results.key(true)
    loser = results.key(false)
    @identity.reload
    assert @identity.valid_password?(winner)
    assert_not @identity.valid_password?(loser)
  end
end
