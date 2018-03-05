#!/bin/bash
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

TMPDIR=`mktemp -d`

trap "{ cd -; rm -rf $TMPDIR; exit 255; }" SIGINT

curl -H "Content-Type:text/plain" "$1" > $TMPDIR/1.png
curl -H "Content-Type:text/plain" "$2" > $TMPDIR/2.png

compare \
  $TMPDIR/1.png $TMPDIR/2.png \
  -compose src \
  $TMPDIR/diff.png

dolphin $TMPDIR
