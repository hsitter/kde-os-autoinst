/*
    Copyright © 2017 Harald Sitter <sitter@kde.org>

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of
    the License or (at your option) version 3 or any later version
    accepted by the membership of KDE e.V. (or its successor approved
    by the membership of KDE e.V.), which shall act as a proxy
    defined in Section 14 of version 3 of the license.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import QtQuick 2.0

Item {
    id: item

    property QtObject rect

    Twiddler {
        id: topTwiddler
        anchors.verticalCenter: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        MouseArea {
            anchors.fill: parent
            drag.target: parent
            drag.axis: Drag.YAxis
            onMouseYChanged: {
                if (!drag.active) {
                    return
                }
                rect.height = rect.height - mouseY
                rect.y = rect.y + mouseY
                if (rect.height < parent.radius) {
                    rect.height = parent.radius
                }
            }
        }
    }

    Twiddler {
        id: rightTwiddler
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.right

        MouseArea {
            anchors.fill: parent
            drag.target: parent
            drag.axis: Drag.XAxis
            onMouseXChanged: {
                if (!drag.active) {
                    return
                }
                rect.width = rect.width + mouseX
                if (rect.width < parent.radius) {
                    rect.width = parent.radius
                }
            }
        }
    }

    Twiddler {
        id: bottomTwiddler
        anchors.verticalCenter: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        MouseArea {
            anchors.fill: parent
            drag.target: parent
            drag.axis: Drag.YAxis
            onMouseYChanged: {
                if (!drag.active) {
                    return
                }
                rect.height = rect.height + mouseY
                if(rect.height < parent.radius) {
                    rect.height = parent.radius
                }
            }
        }
    }

    Twiddler {
        id: leftTwiddler
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.left

        MouseArea {
            anchors.fill: parent
            drag.target: parent
            drag.axis: Drag.XAxis
            onMouseXChanged: {
                if (!drag.active) {
                    return
                }
                rect.width = rect.width - mouseX
                rect.x = rect.x + mouseX
                if (rect.width < parent.radius) {
                    rect.width = parent.radius
                }
            }
        }
    }
}
