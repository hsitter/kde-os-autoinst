# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require 'fileutils'
require 'json'
require 'jenkins_junit_builder'

# JUnit converter.
class JUnit
  BUILD_URL = ENV.fetch('BUILD_URL', nil)

  # Case wrapper
  class Case < JenkinsJunitBuilder::Case
    RESULT_MAP = {
      'ok' => JenkinsJunitBuilder::Case::RESULT_PASSED,
      'fail' => JenkinsJunitBuilder::Case::RESULT_FAILURE
      # => JenkinsJunitBuilder::Case::RESULT_SKIPPED
    }.freeze

    EXPECTATION_URL = 'https://raw.githubusercontent.com/apachelogger/kde-os-autoinst/master'.freeze

    def initialize(detail)
      super()
      # FIXME: we are fetching the tags here because we have no way to either
      # iterate on the tags or the needles right now. Also, the needle format
      # is somewhat inconsistent.
      # Sometimes it is a flat with needle being a property of the detail
      # and other times it is a needles array with multiple needles that have
      # a name property.
      # Not entirely sure how to best handle this.
      self.name = detail.fetch('tags').fetch(0)
      self.result = RESULT_MAP.fetch(detail.fetch('result'))
      system_err.message = JSON.pretty_generate(detail)
      return unless BUILD_URL
      [detail['screenshot'], detail['text']].compact.each do |artifact|
        system_out << "#{artifact_info(artifact, detail)}\n\n"
      end
    end

    def artifact_info(artifact, detail)
      case result
      when JenkinsJunitBuilder::Case::RESULT_PASSED
        return artifact_info_passed(artifact, detail)
      when JenkinsJunitBuilder::Case::RESULT_FAILURE
        return artifact_info_failure(artifact, detail)
      end
      raise
    rescue KeyError => e
      # A detail raised a keyerror. Rescue it with a default message.
      warn e
      artifact_url(artifact)
    end

    def artifact_url(artifact)
      "#{BUILD_URL}/artifact/wok/testresults/#{artifact}"
    end

    def artifact_info_passed(artifact, detail)
      <<-EOF
#{artifact_url(artifact)}
matched:
#{EXPECTATION_URL}/#{detail.fetch('json').sub('.json', '.png')}
      EOF
    end

    def artifact_info_failure(artifact, detail)
      expected_urls = detail.fetch('needles').each do |needle|
        "#{EXPECTATION_URL}/#{needle.fetch('json').sub('.json', '.png')}"
      end
      <<-EOF
#{artifact_url(artifact)}
expected any of:
#{expected_urls.join("\n")}
      EOF
    end
  end

  # Suite wrapper
  class Suite < JenkinsJunitBuilder::Suite
    def initialize(test_file)
      super()
      data = JSON.parse(File.read(test_file))
      self.name = File.basename(test_file).match(/result-(.+)\.json/)[1]
      self.package = name
      self.report_path = "junit/#{name}.xml"
      casify(data)
    end

    def casify(data)
      data.fetch('details').each do |detail|
        # Skip unknown results.
        next if detail.fetch('result') == 'unk'
        # Discard bits that aren't related to a needle tag.
        # FIXME: text items can have a title but no tags. should fall back?
        next unless detail['tags']
        c = Case.new(detail)
        c.name = format('%03d_%s', @cases.size, c.name)
        add_case(c)
      end
      add_case(meta_case(data))
    end

    def meta_case(data)
      c = JenkinsJunitBuilder::Case.new
      c.name = 'all'
      c.result = Case::RESULT_MAP.fetch(data.fetch('result'))
      c
    end
  end

  def self.from_openqa(testresults_dir)
    FileUtils.rm_rf('junit') if Dir.exist?('junit')
    Dir.mkdir('junit')
    ran = false
    Dir.glob("#{testresults_dir}/result-*.json").each do |test_file|
      ran = true
      suite = Suite.new(test_file)
      suite.write_report_file
    end
    return if ran
    raise "Could not find a single test file: #{testresults_dir}/result-*.json!"
  end
end
