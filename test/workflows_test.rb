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
    assert_includes workflow, '(cd dist && sha256sum *.gem > SHA256SUMS)'
  end
end
