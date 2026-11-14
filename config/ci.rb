# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Yarn vulnerability audit", "yarn audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  # One run, so SimpleCov judges the 100% gate on the whole suite.
  step "Tests: All", "bin/rails test:all"
end
