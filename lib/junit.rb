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
  REV = Dir.chdir(File.realpath("#{__dir__}/../")) do
    `git rev-parse HEAD`.strip
  end

  # Case wrapper
  class Case < JenkinsJunitBuilder::Case
    RESULT_MAP = {
      'ok' => JenkinsJunitBuilder::Case::RESULT_PASSED,
      'fail' => JenkinsJunitBuilder::Case::RESULT_FAILURE
      # => JenkinsJunitBuilder::Case::RESULT_SKIPPED
    }.freeze

    REPO = 'apachelogger/kde-os-autoinst'.freeze
    EXPECTATION_URL =
      format('https://raw.githubusercontent.com/%s/%s',
             REPO,
             REV && !REV.empty? ? REV : 'master').freeze

    def initialize(detail)
      super()
      # FIXME: we are fetching the tags here because we have no way to either
      # iterate on the tags or the needles right now. Also, the needle format
      # is somewhat inconsistent.
      # Sometimes it is a flat with needle being a property of the detail
      # and other times it is a needles array with multiple needles that have
      # a name property.
      # Not entirely sure how to best handle this.
      self.name = find_name_of(detail)
      self.result = RESULT_MAP.fetch(detail.fetch('result'))
      system_err.message = JSON.pretty_generate(detail)
      return unless BUILD_URL
      [detail['screenshot'], detail['text']].compact.each do |artifact|
        system_out << "#{artifact_info(artifact, detail)}\n\n"
      end
    end

    def find_name_of(detail)
      tags = detail.fetch('tags')
      return tags.fetch(0) unless tags.empty?
      # Certain tests can produce an empty list of tags (e.g. if no needle
      # was set or the needle wasn't found). To deal with those we'll set a
      # classname and use the screenshot or text as name.
      self.classname = 'notags'
      detail.fetch('screenshot') { detail.fetch('text') }
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
      expected_urls = detail.fetch('needles').collect do |needle|
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
    BAD_RESULTS = [JenkinsJunitBuilder::Case::RESULT_FAILURE,
                   JenkinsJunitBuilder::Case::RESULT_ERROR].freeze

    def initialize(test_file, name:)
      super()
      @failed = false
      data = JSON.parse(File.read(test_file))
      self.name = name
      self.package = name
      self.report_path = "junit/#{name}.xml"
      casify(data)
    end

    def failed?
      @failed
    end

    def add_case(c)
      @failed ||= BAD_RESULTS.include?(c.result)
      super
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

  attr_reader :testresults_dir

  def initialize(testresults_dir)
    @testresults_dir = testresults_dir
    @failed = false
    FileUtils.rm_rf('junit') if Dir.exist?('junit')
    Dir.mkdir('junit')
  end

  def failed?
    @failed
  end

  def tests
    @tests ||= begin
      tests_order_file = "#{testresults_dir}/test_order.json"
      unless File.exist?(tests_order_file)
        raise "No tests run; can't find #{tests_order_file}"
      end
      JSON.parse(File.read(tests_order_file))
    end
  end

  def write_all
    if tests.empty?
      raise "No tests run; order array is empty in #{tests_order_file}"
    end
    tests.each_with_index do |test_h, i|
      name = test_h.fetch('name')
      test_file = "#{testresults_dir}/result-#{name}.json"
      suite = Suite.new(test_file, name: format('%03d_%s', i, name))
      @failed ||= suite.failed?
      suite.write_report_file
    end
  end

  def self.from_openqa(testresults_dir)
    unit = new(testresults_dir)
    unit.write_all
    raise 'It seems some tests have not quite passed' if unit.failed?
  end
end
