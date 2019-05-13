# frozen_string_literal: true
#
# Copyright (C) 2017-2018 Harald Sitter <sitter@kde.org>
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

require_relative 'result'

# JUnit converter.
class JUnit
  BUILD_URL = ENV.fetch('BUILD_URL', nil)
  REV = Dir.chdir(File.realpath("#{__dir__}/../")) do
    `git rev-parse HEAD`.strip
  end

  class Case < JenkinsJunitBuilder::Case
    RESULT_MAP = {
      ok: JenkinsJunitBuilder::Case::RESULT_PASSED,
      fail: JenkinsJunitBuilder::Case::RESULT_FAILURE,
      unknown: JenkinsJunitBuilder::Case::RESULT_PASSED,
      softfail: JenkinsJunitBuilder::Case::RESULT_PASSED,
      # It's actually unclear why canceled appears. Code suggests it's set when
      # the test runner gets TERM. Question is why it would I guess. In any
      # event we'll consider this a failure.
      canceled: JenkinsJunitBuilder::Case::RESULT_FAILURE
      # => JenkinsJunitBuilder::Case::RESULT_SKIPPED
    }.freeze

    REPO = 'apachelogger/kde-os-autoinst'.freeze
    EXPECTATION_URL =
      format('https://raw.githubusercontent.com/%s/%s',
             REPO,
             REV && !REV.empty? ? REV : 'master').freeze

    attr_reader :detail

    def initialize(detail)
      super()
      @detail = detail
      self.result = translate_result(detail.result)
      if result == JenkinsJunitBuilder::Case::RESULT_PASSED &&
         detail.dent
        # iff this detail has a dent mark it skipped in junit; best
        # representation we have.
        self.result = JenkinsJunitBuilder::Case::RESULT_SKIPPED
      end
      system_err.message = JSON.pretty_generate(detail.data)
    end

    def translate_result(r)
      RESULT_MAP.fetch(detail.result)
    end

    def artifact_url(artifact)
      "#{BUILD_URL}/artifact/testresults/#{artifact}"
    end
  end

  class TextDetailCase < Case
    def initialize(detail)
      super
      self.name = detail.title
      system_out << artifact_url(detail.text)
    end
  end

  class SoftFailureDetailCase < Case
    def initialize(detail)
      # Soft failures are difficult in that their result field is in fact
      # a screenshot blob. We always mark them skipped and do our best
      # to give useful data.
      super
      self.name = detail.title
      screenshot = ''
      # In newer os-autoinst softfails may also simply have result:softfail
      # instead of nesting another detail with screenshot. In that case
      # we have nothing to add and can simply leave the empty string
      unless detail.result.is_a?(Symbol)
        screenshot = artifact_url(detail.result.screenshot)
      end
      system_out << <<-STDOUT
We recorded a soft failure, this isn't a failed assertion but rather
indicates that something is (temporarily) wrong with the expecations.
This event was programtically created, check the code of the test case.
#{artifact_url(detail.text)}
#{screenshot}
STDOUT
    end

    # always mark skipped
    def translate_result(_r)
      JenkinsJunitBuilder::Case::RESULT_SKIPPED
    end
  end

  class ScreenshotDetailCase < Case
    def initialize(detail)
      super
      self.name = 'screenshot_without_match'
      system_out << artifact_url(detail.screenshot)
    end
  end

  class NeedleDetailCase < Case
    def initialize(detail)
      super
      self.name = 'unmatched_needle'
      if detail.result == :unknown
        system_out << "This was a check but not an assertion!!!\n"
      end
      case detail.result
      when :ok then system_out << ok_needles_info
      when :fail, :unknown then system_out << error_needles_info
      end
    end

    def ok_needles_info
      <<-STDOUT
#{artifact_url(detail.screenshot)}
matched:
#{EXPECTATION_URL}/#{detail.json.sub('.json', '.png')}
      STDOUT
    end

    def error_needles_info
      return no_needles_info if detail.needles.empty?
      expected_urls = detail.needles.collect do |needle|
        "#{EXPECTATION_URL}/#{needle.json.sub('.json', '.png')}"
      end
      <<-STDOUT
To satisfy a test for the tags '#{detail.tags}' we checked the screen and found
#{artifact_url(detail.screenshot)}
but expected any of:
#{expected_urls.join("\n")}
      STDOUT
    end

    def no_needles_info
      <<-STDOUT
We wanted to test for tags '#{detail.tags}' but found no needles to back these
tags. Chances are there is no needle, or the tags are misspelled.
(Other options apply but are less likely obviously.)

#{artifact_url(detail.screenshot)}
      STDOUT
    end
  end

  class NeedleMatchDetailCase < NeedleDetailCase
    def initialize(detail)
      super
      self.name = detail.needle
    end
  end

  # Suite wrapper
  class Suite < JenkinsJunitBuilder::Suite
    BAD_RESULTS = [JenkinsJunitBuilder::Case::RESULT_FAILURE,
                   JenkinsJunitBuilder::Case::RESULT_ERROR].freeze

    def initialize(test_file, name:)
      super()
      @failed = false
      result = OSAutoInst::ResultSuite.new(test_file)
      self.name = name
      self.package = name
      self.report_path = "junit/#{name}.xml"
      casify(result)
    end

    def failed?
      @failed
    end

    def add_case(c)
      @failed ||= BAD_RESULTS.include?(c.result)
      super
    end

    def casify(result)
      result.details.each do |detail|
        case_klass = detail.class.to_s.split('::')[-1] + 'Case'
        c = JUnit.const_get(case_klass).new(detail)
        c.name = format('%03d_%s', @cases.size, c.name)
        add_case(c)
      end
      add_case(meta_case(result))
    end

    def meta_case(result)
      c = JenkinsJunitBuilder::Case.new
      c.name = 'all'
      c.result = Case::RESULT_MAP.fetch(result.result)
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

  def write_all
    order = OSAutoInst::TestOrder.new(testresults_dir: testresults_dir)
    if order.tests.empty?
      raise "No tests run; order array is empty in #{order.file}"
    end
    order.tests.each_with_index do |test, i|
      name = test.fetch(:name)
      test_file = test.fetch(:file)
      assert_test_file(name, test_file)
      suite = Suite.new(test_file, name: format('%03d_%s', i, name))
      @failed ||= suite.failed?
      suite.write_report_file
    end
  end

  def assert_test_file(name, file)
    return if File.exist?(file)
    raise "Test '#{name}' has a missing json file; it probably failed entirely"
  end

  def self.from_openqa(testresults_dir)
    unit = new(testresults_dir)
    unit.write_all
    raise 'It seems some tests have not quite passed' if unit.failed?
  end
end
