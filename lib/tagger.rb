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

  def parse_tags
    tags = []

    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{opts.program_name} [options] -t tag FILES"

      opts.on('-t', '--tag HOST',
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
    files = ARGV.collect { |x| [x, JSON.parse(File.read(x))] }.to_h
    files.each_value do |json|
      json_tags = json.fetch('tags')
      yield tags, json_tags
      json['tags'] = json_tags
    end

    files.each do |file, json|
      data = JSON.pretty_generate(json)
      data += "\n" unless data.end_with?("\n")
      File.write(file, data)
    end
  end
end
