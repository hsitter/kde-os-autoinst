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

module OSAutoInst
  class GenericDetailError < StandardError; end

  module DetailAttributes
    def detail_attributes
      @detail_attributes ||= []
    end

    def detail_attributes_optional
      @detail_attributes_optional ||= []
    end

    def attributes
      @attrs ||= begin
        attrs = detail_attributes.dup
        attrs += ancestors.collect do |klass|
          next if klass == self || !klass.respond_to?(:attributes)
          klass.attributes
        end.flatten.uniq.compact
        attrs.flatten.uniq.compact
      end
    end

    def optional_attributes
      @optional_attrs ||= begin
        attrs = detail_attributes_optional.dup
        attrs += ancestors.collect do |klass|
          next if klass == self || !klass.respond_to?(:detail_attributes_optional)
          klass.detail_attributes_optional
        end.flatten.uniq.compact
        attrs.flatten.uniq.compact
      end
    end

    def all_attributes
      (attributes + optional_attributes).uniq.compact
    end

    def detail_attr(sym)
      detail_attributes << sym
      attr_reader_real sym
    end

    # Optionals are different. They may appear or not. Main example is a 'dent'.
    # Pretty much all details may be marked as having a dent, i.e. they passed
    # but not very nicely.
    def optional_detail_attr(sym)
      detail_attributes_optional << sym
      attr_reader_real sym
    end

    def self.extended(other)
      class << other
        alias_method :attr_reader_real, :attr_reader
        def attr_reader(*)
          raise 'When you want a public detail attribute use `detail attr`. When you want an actual reader use attr_reader_real'
        end
      end
    end
  end

  class DetailRepresentation
    extend DetailAttributes

    attr_reader_real :data

    class << self
      def can_represent_exactly?(data_blob)
        data_blob.keys.sort == attributes.sort ||
          data_blob.keys.sort == all_attributes.sort
      end

      def can_represent_approximately?(data_blob)
        (data_blob.keys.sort - attributes.sort).empty? ||
          (data_blob.keys.sort - all_attributes.sort).empty?
      end

      def need?(_data)
        false
      end

      def want?(_data)
        true
      end
    end

    def initialize(data)
      @data = data
      data.each do |key, value|
        var = "@#{key}"
        instance_variable_set(var, value)
      end
    end
  end

  class Detail < DetailRepresentation
    # :ok or :fail or :unknown or :skip
    detail_attr :result

    # Dents are optional markers to mark a result as not quite as good
    # as should be. (e.g. it matched but only using a workaround needle).
    # If I am not mistaken the primary cause for a dent is a workaround property
    optional_detail_attr :dent

    def initialize(*)
      # os-autoinst may create result blobs which contain no worthwhile
      # information. These blobs will match the Detail class directly. Detail
      # however is not meant to be used directly as it cannot be represented
      # in junit with any worthwhile information. Simply put a generic detail
      # means nothing so it shouldn't be used. This error needs to be handled
      # when factorizing details.
      raise GenericDetailError if self.class == Detail

      @dent ||= false
      super
      init_result
    end

    def init_result
      results = { 'unk' => :unknown, 'ok' => :ok, 'fail' => :fail }
      @result = results.fetch(result) do
        result.is_a?(Hash)
        begin
          @result = DetailFactory.new(result).factorize
        rescue
          raise "Couldn't map result #{result}"
        end
      end
    end

    # Returns the ultimate result. Result may be another detail (e.g.
    # a screenshot). This method loops into results until it reaches a type
    # that no longer has a result method (i.e. hopefully one of the well-known
    # symbols).
    def deep_result
      ret = result
      loop do
        break unless ret.respond_to?(:result)
        ret = ret.result
      end
      ret
    end

    def coerce_result(r)
      # FIXME: probably should make sure only unknown gets coerced
      @result = r
    end

    # Whether or not this detail is equal to another detail in terms of its
    # functional properties. e.g. details with a tag can be the same if the
    # tags are the same.
    # This does not assert equallity (different results can still be the same
    # detail).
    # Sameness is used to determine chains of details with unknown results
    # and finalize their result to whatever was the final result. Namely
    # Needle matches can have multiple "unknown" result details which
    # essentially means a screenshot was taken and compared, but didn't match
    # and there is still time for another screenshot to match.
    def same?(_other)
      false
    end
  end

  # A screenshot which was taken but didn't match a needle.
  class ScreenshotDetail < Detail
    # File name of associated screenshot.
    detail_attr :screenshot
    # The Range during which the frame was taken. As Frames are only fetched
    # at a certain interval, each frame appears within a range of time rather
    # than fixed points.
    detail_attr :frametime
  end

  # A text assertion
  class TextDetail < Detail
    # a custom title for the test
    detail_attr :title
    # received textual output
    detail_attr :text
  end

  # Soft failures are text details with rubbish result...
  class SoftFailureDetail < TextDetail
    # Result gets automatically represented correctly as it is a Hash.
    # This class is only here so we can easily render this type of failure
    # differently when converting to junit.

    def self.need?(data)
      data[:result] && data[:result].is_a?(Hash)
    end

    def self.want?(data)
      data[:result] && data[:result].is_a?(Hash)
    end
  end

  class NeedleDetail < Detail
    detail_attr :frametime
    # Array of ErrorNeedles
    detail_attr :needles
    detail_attr :screenshot # screenshot of the assertion
    detail_attr :tags # tags searched for
    detail_attr :error # for the live of me I don't know what this shit is

    def initialize(*)
      # Init to avoid problems with representing approximate blobs.
      @needles = []
      @tags = []
      super
      return unless @needles
      @needles = @needles.collect { |x| DetailFactory.new(x).factorize }
    end

    # Needle types can appear in chains that have sameness. Make sure we are
    # same enough to previous potentially unknown needles.
    def same?(other)
      return false unless other.is_a?(self.class)
      # If the tags are the same and the needles are the same. Or so I think.
      tags.sort == other.tags.sort
    end
  end

  module Needle
    extend DetailAttributes

    detail_attr :area # Array of matching areas
    detail_attr :json # json file of the needle
    detail_attr :needle # string, name of needle
    def needle
      @needle || @name
    end
    # In a needles:{} the detail is refering to the name as name, in a match
    # it refers to it as needle. Inconsistent shitfest. Compatibility the
    # two incarnations.
    # A Detail that includes Needle never exactly matches because of this. Not
    # a problem right now, but if it becomes one in the future this needs
    # splitting into NeedleMatch and NeedleInfo respectively using the correct
    # attr name.
    detail_attr :name # string, name of NeedleError
    def name
      @name || @needle
    end
  end

  # this is not actually a high level detail, it appears within needle details.
  class NeedleError < DetailRepresentation
    prepend Needle

    detail_attr :error
  end

  class NeedleMatchDetail < NeedleDetail
    prepend Needle

    detail_attr :properties # of the matched needle
  end

  # # This is not a detail! FML.
  # class SoftFailure < Detail
  #   def self.can_represent?(data_blob)
  #     super && data_blob.fetch(:title) == 'Soft Failure'
  #   end
  #
  #   # NB: Result is ScreenshotDetail object!!!@#!!!!!!
  #   # Title (always says it is a soft failure, details are in text)
  #   detail_attr :title
  #   # the software failure description
  #   detail_attr :text
  # end

  class DetailFactory
    attr_reader :data

    def initialize(data)
      @data = data
      @representations = []
      @approximations = []
    end

    def find_klasses
      @representations = OSAutoInst.constants.collect do |const|
        klass = OSAutoInst.const_get(const)
        next unless klass.is_a?(Class) &&
                    klass.ancestors.include?(DetailRepresentation)
        unless klass.can_represent_exactly?(data)
          @approximations << klass if klass.can_represent_approximately?(data)
          next
        end
        klass
      end.compact
    end

    # If multiple classes can represent the same data set we essentially
    # X-OR them. We ask all of them if they want the data. If >1 wants it
    # we ask if they need the data.
    # This allows a class to override all other classes by needing data it
    # absolutely knows how to handle while also being able to not want data
    # which it knows other classes can handle better.
    # Notably both TextDetail and SoftFailureDetail can handle textish blobs
    # BUT only SoftFailureDetail knows how to differentiate a soft failure blob
    # from a regular text blob. As such both can technically represent a
    # textis blob but SoftFailureDetail only wants soft failure blobs.
    def who_needs_the_data
      @representations = @representations.select { |x| x.need?(data) }
      case @representations.size
      when 0 then return
      when 1 then return @representations[0]
      else raise "to many klasses need the data #{@representations} #{data}"
      end
    end

    # Check who wants the data.
    # If there are multiple, check who needs the data.
    # If no one needs the data use the least shitty approximation to who wants
    # the data.
    #
    # If no one needs the data we'll assume they can all handle the data
    # (as they wanted it) but are indifferent as to which gets it, so we'll
    # simply use the tighest approximation. i.e. the one with less attributes.
    # (an approximate match has a superset of attributes in the blob, so
    # the smallest super set becomes the best match).
    # e.g. {tags:,foo:} approximates to classes {tags:,foo:,bar:} and
    #   {tags:,foo:,bar:,foobar:}. the former class is the match with less
    #   presumed functional overhead though.
    def who_wants_the_data
      @representations = @representations.select { |x| x.want?(data) }
      weighted_by_attributes = @representations.sort do |x, y|
        x.attributes.size <=> y.attributes.size
      end
      case @representations.size
      when 0 then raise "no classes wanted our data #{data}"
      when 1 then return @representations[0]
      end
      need = who_needs_the_data
      return need if need
      approximation = weighted_by_attributes.fetch(0)
      warn "No class needed so we'll approximat with #{approximation} - #{data}"
      approximation
    end

    class NoPerfectMatchError < RuntimeError; end

    def best_klass
      case @representations.size
      when 0
        raise NoPerfectMatchError unless @representations == @approximations
        raise "no representation for #{data}"
      when 1 then @representations[0]
      else who_wants_the_data
      end
    rescue NoPerfectMatchError
      @representations = @approximations
      retry
    end

    def factorize
      find_klasses
      best_klass.new(data)
    rescue GenericDetailError
      warn "Encountered generic detail, skipping: #{data}}"
      nil
    rescue NoMethodError => e
      warn "Failed to find class for #{data}"
      raise e
    end
  end

  class ResultSuite
    # Result :ok or :fail or :canceled
    attr_reader :result
    # TODO: unknown
    attr_reader :dents

    # The actual assertions
    attr_reader :details

    # Edit all details to sort out chain failures.
    # openqa records results not necessarily assertions. To meet a screen
    # assertion for 'grub' it may take multiple screenshots which may get
    # recorded as unknown. The last of them may be fail if no match was found
    # and the time ran out. In these cases we do however want to make the
    # entire chain of unknown preceding details fail as well. Otherwise its
    # hard to find out where things started to fail.
    # This requires that details that can appear in a fail chain implement
    # the {same?} method to check if they qualify as the same check as
    # another detail. This way we can build chains of sameish checks and let
    # them all fail or succeed as needed.
    def chain_fail
      running_array = []
      @details.each do |detail|
        # If the detail is not compatible with the unknown details in the chain
        # the chain was broken for unknown reasons and we cannot finalize the
        # results of the unknown details.
        running_array = [] unless detail.same?(running_array[0])
        # Get the deep result. We'll make assertions on its typyness.
        result = detail.deep_result
        if %i[ok fail].include?(result)
          # Finalize.
          running_array.each { |x| x.coerce_result(detail.result) }
          running_array = []
          next
        end
        # Otherwise the detail is one more in the chain of unknown.
        raise unless result == :unknown # assert
        running_array << detail
      end
    end

    def initialize(path)
      data = JSON.parse(File.read(path), symbolize_names: true)
      @dents = data.delete(:dents)
      @result = data.delete(:result)
      @result = case @result
                when 'ok' then :ok
                when 'fail' then :fail
                when 'canceled' then :canceled
                else raise "Unknown result #{@result}"
                end
      @details = data.delete(:details)
      # also compact drop possible nil results (e.g. generic details)
      @details = @details.collect { |x| DetailFactory.new(x).factorize }.compact
      chain_fail
      raise unless data.keys.empty?
    end
  end

  class TestOrder
    attr_reader :file
    attr_reader :testresults_dir

    attr_reader :tests

    def initialize(testresults_dir:)
      @testresults_dir = testresults_dir
      @file = "#{testresults_dir}/test_order.json"
      raise "No tests run; can't find #{@file}" unless File.exist?(@file)
      @tests = JSON.parse(File.read(@file), symbolize_names: true)
      extend_data!
    end

    def test_files
      tests.collect { |t| t.fetch(:file) }
    end

    def result_suites
      # missing files are ignored. Could also make this opt-in fatal. No use
      # for this as junit (which wants to fail) does so in its own code
      test_files.collect do |test_file|
        next nil unless File.exist?(test_file)
        ResultSuite.new(test_file)
      end.compact
    end

    private

    def extend_data!
      tests.each do |test|
        test[:file] = "#{testresults_dir}/result-#{test.fetch(:name)}.json"
      end
    end
  end
end
