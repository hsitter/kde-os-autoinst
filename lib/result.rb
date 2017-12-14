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

module OSAutoInst
  module DetailAttributes
    def attributes
      @attrs ||= begin
        attrs = @detail_attributes || []
        attrs += ancestors.collect do |klass|
          next if klass == self || !klass.respond_to?(:attributes)
          klass.attributes
        end.flatten.uniq.compact
        attrs.flatten.uniq.compact
      end
    end

    def detail_attr(sym)
      (@detail_attributes ||= []) << sym
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
        data_blob.keys.sort == attributes.sort
      end

      def can_represent_approximately?(data_blob)
        (data_blob.keys.sort - attributes.sort).empty?
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
    # :ok or :fail or :unknown
    detail_attr :result

    def initialize(*)
      super
      results = { 'unk' => :unknown, 'ok' => :ok, 'fail' => :fail }
      @result = results.fetch(result) { raise "Couldn't map result #{result}" }
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

  class NeedleDetail < Detail
    detail_attr :frametime
    # Array of ErrorNeedles
    detail_attr :needles
    detail_attr :screenshot # screenshot of the assertion
    detail_attr :tags # tags searched for

    def initialize(*)
      super
      return unless @needles
      @needles = @needles.collect { |x| DetailFactory.new(x).factorize }
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

    class NoPerfectMatchError < RuntimeError; end

    def best_klass
      case @representations.size
      when 0
        raise NoPerfectMatchError unless @representations == @approximations
        raise "no representation for #{data}"
      when 1 then @representations[0]
      else raise "to many klasses match this #{@representations}"
      end
    rescue NoPerfectMatchError
      @representations = @approximations
      retry
    end

    def factorize
      find_klasses
      best_klass.new(data)
    end
  end

  class ResultSuite
    # Result :ok or :fail
    attr_reader :result
    # TODO: unknown
    attr_reader :dents

    # The actual assertions
    attr_reader :details

    def initialize(path)
      data = JSON.parse(File.read(path), symbolize_names: true)
      @dents = data.delete(:dents)
      @result = data.delete(:result)
      @result = case @result
                when 'ok' then :ok
                when 'fail' then :fail
                else raise "Unknown result #{@result}"
                end
      @details = data.delete(:details)
      @details = @details.collect { |x| DetailFactory.new(x).factorize }
      raise unless data.keys.empty?
    end
  end
end
