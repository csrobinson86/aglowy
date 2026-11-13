---
name: Story
about: One small, testable change that becomes one pull request
title: "[EPIC-NN] "
labels: story
---

## Goal

<!-- One sentence: what someone can do, or what's true, when this is merged. -->

## Why

<!-- The goal in docs/product/vision.md this serves, and the design doc section it implements. -->

## Scope

<!-- Numbered steps the builder follows. Name files, models and routes. -->

## Out of scope

<!-- What this story must not touch. The reviewer checks the PR against this list. -->

## Acceptance tests

<!-- Named tests, written first. The reviewer checks each one exists. -->

- [ ] `test/...`: ...

## Traps

<!-- Things likely to go wrong, from the design doc's gotchas or the current code. -->

## Definition of done

- [ ] Acceptance tests written first and passing
- [ ] `bin/rails test:all` green; coverage not lowered
- [ ] `bin/rubocop` and `bin/brakeman` clean
- [ ] `code-reviewer` subagent run: verdict "Ready to merge" or Majors fixed
- [ ] Diff under ~400 changed lines (excluding `db/schema.rb`), or the size is explained in the PR

## Commit / PR title

<!-- e.g. `Sign up creates a household with its head` -->

**Depends on:** <!-- #issue numbers, or "none" -->
