#!/usr/bin/env ruby
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

require 'erb'
require 'pathname'
require_relative '../lib/result'

OUTPUT_FILE = File.absolute_path(ARGV[0])
BUILD_URL = ENV.fetch('BUILD_URL', nil)
# Jenkins: archives inside wok/, so we need to be relative to wok/.
# Local: use reference from pwd.
BASEDIR = BUILD_URL ? 'testresults' : 'wok/testresults'

pictures = []

testresults_dir = 'wok/testresults'
order = OSAutoInst::TestOrder.new(testresults_dir: testresults_dir)
order.result_suites.each do |suite|
  suite.details.each do |detail|
    next unless detail.respond_to?(:screenshot)
    pictures << detail.screenshot
  end
end

pictures = pictures.collect { |x| File.join(BASEDIR, x) }
template = ERB.new(DATA.read)
render = template.result(binding)
File.write(ARGV[0], render)

# Other interesting options for galleries
# http://manos.malihu.gr/sideways-jquery-fullscreen-image-gallery/
# http://www.efectorelativo.net/laboratory/noobSlide/
# https://alistapart.com/article/imagegallery
# https://galleria.io/
# http://photoswipe.com/

__END__

<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js"></script> <!-- 33 KB -->

<!-- fotorama.css & fotorama.js. -->
<link  href="https://cdnjs.cloudflare.com/ajax/libs/fotorama/4.6.4/fotorama.css" rel="stylesheet"> <!-- 3 KB -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/fotorama/4.6.4/fotorama.js"></script> <!-- 16 KB -->

<!-- 2. Add images to <div class="fotorama"></div>. -->
<div class="fotorama"
  data-keyboard="true"
  data-nav="thumbs"
  data-arrows="true"
  data-click="true"
>
  <% pictures.each do |picture| %>
    <a href="<%= picture %>"></a>
  <% end %>
</div>
