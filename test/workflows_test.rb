# frozen_string_literal: true

require_relative 'test_helper'

class WorkflowsTest < Minitest::Test
  WORKFLOWS = Dir[File.expand_path('../.github/workflows/*.yml', __dir__)].freeze

  def test_all_actions_are_pinned_to_full_commit_shas
    uses = WORKFLOWS.flat_map { |file| File.readlines(file).grep(/^\s*- uses:/) }

    refute_empty uses
    uses.each { |line| assert_match(/@[0-9a-f]{40}(?:\s|$)/, line) }
  end

  def test_release_is_github_first_and_rubygems_is_manual_only
    workflow = File.read(File.expand_path('../.github/workflows/release.yml', __dir__))

    assert_includes workflow, 'GH_REPO: ${{ github.repository }}'
    assert_includes workflow, "github.event_name == 'workflow_dispatch' && inputs.publish_rubygems == true"
    assert_includes workflow, 'git merge-base --is-ancestor HEAD origin/main'
    assert_includes workflow, '(cd dist && sha256sum -- ./*.gem > SHA256SUMS)'
    assert_includes workflow, "tags: ['v*']"
    assert_includes workflow, 'needs: [verify-and-build, attest-build-provenance]'
    assert_includes workflow, 'subject-path: dist/*'
    assert_includes workflow, 'gh release create "$RELEASE_TAG"'
    refute_includes workflow, 'types: [published]'
    refute_includes workflow, '--clobber'
    assert_includes workflow, "github.event_name == 'push' && github.sha || inputs.tag"
    assert_includes workflow, "EVENT_SHA: ${{ github.event_name == 'push' && github.sha || '' }}"
    assert_includes workflow, 'SOURCE_DATE_EPOCH="$(git show -s --format=%ct HEAD)"'
    assert_includes workflow, 'gh release download "$RELEASE_TAG"'
    assert_includes workflow, 'gh release view "$RELEASE_TAG" --json isDraft --jq .isDraft'
    assert_includes workflow, 'test "$(gh release view "$RELEASE_TAG" --json isDraft --jq .isDraft)" = false'
  end
end
