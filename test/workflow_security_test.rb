# frozen_string_literal: true

require_relative 'test_helper'

class WorkflowSecurityTest < Minitest::Test
  def test_untrusted_github_expressions_are_not_embedded_in_run_scripts
    workflows = Dir[File.expand_path('../.github/workflows/*.{yml,yaml}', __dir__)]

    violations = workflows.flat_map do |path|
      run_blocks(path).filter_map do |line_number, body|
        "#{File.basename(path)}:#{line_number}" if body.include?('${{')
      end
    end

    assert_empty violations, "GitHub expressions in run scripts can enable command injection: #{violations.join(', ')}"
  end

  private

  def run_blocks(path)
    lines = File.readlines(path)
    blocks = []
    index = 0
    while index < lines.length
      match = lines[index].match(/^(\s*)(?:-\s+)?run:\s*(.*)$/)
      unless match
        index += 1
        next
      end

      indent = match[1].length
      body = match[2].dup
      start = index + 1
      index += 1
      while index < lines.length && (lines[index].strip.empty? || lines[index][/^\s*/].length > indent)
        body << lines[index]
        index += 1
      end
      blocks << [start, body]
    end
    blocks
  end
end
