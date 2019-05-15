#!/usr/bin/env ruby
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License or (at your option) version 3 or any later version
# accepted by the membership of KDE e.V. (or its successor approved
# by the membership of KDE e.V.), which shall act as a proxy
# defined in Section 14 of version 3 of the license.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Generic setup helper for basetests.
# In here you should do all things that make sense for all tests as default
# behavior (certain tests can still opt out by undoing whatever is done etc).
# This is all in one file to speed things up. Running invidiual commands is
# slower in os-autoinst, and since this all counts as the same script...

# This is already done in the installation first_start, but we'll do it
# here again to be on the save side.
puts "#{$0} Disabling snapd."
system 'systemctl disable --now snapd.refresh.timer'
system 'systemctl disable --now snapd.refresh.service'
system 'systemctl disable --now snapd.snap-repair.timer'
system 'systemctl disable --now snapd.service'

# FIXME: temporary here until all base images got respun.
puts "#{$0} Adding systemd-coredump."
system 'apt update' || raise
system 'apt install -y systemd-coredump' || raise

file = '/usr/share/plasma/plasmoids/org.kde.plasma.kickoff/contents/ui/KickoffListView.qml'
File.write(file, <<-EOF)
/*
    Copyright (C) 2011  Martin Gräßlin <mgraesslin@kde.org>
    Copyright (C) 2012  Gregor Taetzner <gregor@freenet.de>
    Copyright (C) 2015-2018  Eike Hein <hein@kde.org>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/
import QtQuick 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.components 2.0 as PlasmaComponents


FocusScope {
    id: view

    signal reset
    signal addBreadcrumb(var model, string title)

    readonly property Item listView: listView
    readonly property Item scrollArea: scrollArea

    property bool showAppsByName: true
    property bool appView: false

    property alias model: listView.model
    property alias delegate: listView.delegate
    property alias currentIndex: listView.currentIndex
    property alias currentItem: listView.currentItem
    property alias count: listView.count
    property alias interactive: listView.interactive
    property alias contentHeight: listView.contentHeight

    property alias move: listView.move
    property alias moveDisplaced: listView.moveDisplaced

    function incrementCurrentIndex() {
        listView.incrementCurrentIndex();
    }

    function decrementCurrentIndex() {
        listView.decrementCurrentIndex();
    }

    Connections {
        target: plasmoid

        onExpandedChanged: {
            if (!expanded) {
                listView.positionViewAtBeginning();
            }
        }
    }

    PlasmaExtras.ScrollArea {
        id: scrollArea
        frameVisible: false
        anchors.fill: parent

        ListView {
            id: listView

            focus: true

            keyNavigationWraps: true
            boundsBehavior: Flickable.StopAtBounds

            highlight: KickoffHighlight {}
            highlightMoveDuration : 0
            highlightResizeDuration: 0

            delegate: KickoffItem {
                id: delegateItem

                appView: view.appView
                showAppsByName: view.showAppsByName

                onReset: view.reset()
                onAddBreadcrumb: view.addBreadcrumb(model, title)
            }

            section {
                property: "group"
                criteria: ViewSection.FullString
                delegate: SectionDelegate {}
            }
        }
    }

    MouseArea {
        anchors.left: parent.left

        width: scrollArea.viewport.width
        height: parent.height

        id: mouseArea

        property Item pressed: null
        property int pressX: -1
        property int pressY: -1

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPressed: {
            console.debug("onPressed %1 %2".arg(mouse.x).arg(mouse.y))
            var mapped = listView.mapToItem(listView.contentItem, mouse.x, mouse.y);
            var item = listView.itemAt(mapped.x, mapped.y);

            if (!item) {
                return;
            }

            if (mouse.buttons & Qt.RightButton) {
                if (item.hasActionList) {
                    mapped = listView.contentItem.mapToItem(item, mapped.x, mapped.y);
                    listView.currentItem.openActionMenu(mapped.x, mapped.y);
                }
            } else {
                pressed = item;
                pressX = mouse.x;
                pressY = mouse.y;
            }
        }

        onReleased: {
            console.debug("onReleased %1 %2".arg(mouse.x).arg(mouse.y))
            var mapped = listView.mapToItem(listView.contentItem, mouse.x, mouse.y);
            var item = listView.itemAt(mapped.x, mapped.y);

            if (item && pressed === item) {
                if (item.appView) {
                    view.state = "OutgoingLeft";
                } else {
                    item.activate();
                }

                listView.currentIndex = -1;
            }

            pressed = null;
            pressX = -1;
            pressY = -1;
        }

        onPositionChanged: {
            console.debug("onPositionChanged %1 %2".arg(mouse.x).arg(mouse.y))
            var mapped = listView.mapToItem(listView.contentItem, mouse.x, mouse.y);
            var item = listView.itemAt(mapped.x, mapped.y);

            if (item) {
                listView.currentIndex = item.itemIndex;
            } else {
                listView.currentIndex = -1;
            }

            if (pressed && pressX != -1 && pressed.url && dragHelper.isDrag(pressX, pressY, mouse.x, mouse.y)) {
                kickoff.dragSource = item;
                dragHelper.startDrag(root, pressed.url, pressed.decoration);
                pressed = null;
                pressX = -1;
                pressY = -1;
            }
        }

        onContainsMouseChanged: {
            console.debug("onContainsMouseChanged %1 %2 %3".arg(containsMouse).arg(mouseX).arg(mouseY))
            if (!containsMouse) {
                pressed = null;
                pressX = -1;
                pressY = -1;
            }
        }

        onEntered: console.debug("onEntered %1 %2 %3".arg(containsMouse).arg(mouseX).arg(mouseY))
    }
}
EOF
