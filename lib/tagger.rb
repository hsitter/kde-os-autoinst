# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

require 'json'
require 'optparse'

module Tagger
  module_function

  Needle = Struct.new(:file, :json, :dirty)

  def parse_tags
    tags = []

    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{opts.program_name} [options] -t tag FILES"

      opts.on('-t', '--tag TAG',
              'tag to change [can be used multiple times ]') do |v|
        tags << v
      end
    end
    parser.parse!

    return tags unless tags.empty?
    abort "No tags passed!\n\n" + parser.help
  end

  def run
    tags = parse_tags

    ARGV.each { |x| abort "Not a file: #{x}" unless File.file?(x) }
    needles = ARGV.collect do |x|
      Needle.new(x, JSON.parse(File.read(x)))
    end

    needles.each do |needle|
      json_tags = needle.json.fetch('tags')
      orig_tags = json_tags.dup
      yield tags, json_tags
      next if json_tags == orig_tags
      needle.dirty = true
      needle.json['tags'] = json_tags
    end

    needles.each do |needle|
      next unless needle.dirty
      data = JSON.pretty_generate(needle.json)
      data += "\n" unless data.end_with?("\n")
      # Qt's JSON.stringify formats empty arrays as [], ruby injects a newline,
      # to avoid useless noise bend ruby accordingly.
      # Somewhat naughty but there doesn't seem to be a switch for this.
      data = data.gsub("\"properties\": [\n\n  ]", '"properties": []')
      File.write(needle.file, data)
    end
  end
end
