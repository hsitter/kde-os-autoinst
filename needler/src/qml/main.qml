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

import QtQuick 2.7
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQml.Models 2.2
import QtQuick.Dialogs 1.2

import privateneedler 1.0 as Needler

ApplicationWindow {
    property string path

    function save() {
        write(selectorModel.toJSON())
    }

    function withoutExtension(str)
    {
        var str = new String(str) // Make sure its a stringy.
        if (str.lastIndexOf(".") != -1) {
            str = str.substring(0, str.lastIndexOf("."));
        }
        return str;
    }

    function load(url) {
        path = withoutExtension(url.toString())
        var json = withoutExtension(path) + ".json"
        var png = withoutExtension(path) + ".png"
        console.debug("loading " + json + " " + png)
        selectorModel.loadFromJSON(json)
        image.source = ""
        image.source = png
    }

    function writeData(path, data) {
        var xhr = new XMLHttpRequest;
        xhr.open("PUT", path);
        xhr.send(data);
    }

    function write(jsonData) {
        console.debug(path)
        var xhr = new XMLHttpRequest;
        xhr.open("PUT", path + ".json");
        xhr.send(jsonData);
    }

    width: 1290
    height: 800
    visible: true

    Component.onCompleted: {
        load(Needler.Application.fileArgument())
    }

//    menuBar: MenuBar {
//        Menu {
//            title: "File"
//            MenuItem {
//                text: "Open..."
//                onTriggered: { fileDialog.open() }
//            }
//            MenuItem {
//                text: "Close"
//                onTriggered: { Qt.quit() }
//            }
//        }
//    }

    FileDialog {
        id: fileDialog
        folder: "neon/needles"
        selectMultiple: false
        nameFilters: [ "Needle files (*.json *png)" ]

        onAccepted: {
            load(fileDialog.fileUrl)
        }
        onRejected: {
            Qt.quit()
        }
    }

    Component {
        id: selector
        Selector { model: selectorModel }
    }

    RowLayout {
        anchors.fill: parent
        ColumnLayout {
            Text { text: "Properties"; color: palette.text }
            TextArea {
                placeholderText: "..."
//                wrapMode: TextEdit.Wrap
                text: selectorModel.properties
                // FIXME: these are binding loops
                // would need async timer or something
                onTextChanged: { selectorModel.properties = text.split(',') }
            }
            Text { text: "Tags"; color: palette.text }
            TextArea {
                placeholderText: "..."
//                wrapMode: TextEdit.Wrap
                text: selectorModel.tags.join(',')
                onTextChanged: { selectorModel.tags = text.split(',') }
            }
            RowLayout {
                Button {
                    text: "Save"
                    onClicked: { save() }
                }
                Button {
                    text: "Quit"
                    onClicked: { Qt.quit() }
                }
            }
        }

        ScrollView {
            id: view

            Layout.fillWidth: true
            Layout.fillHeight: true

            // Not sure why but auto-calc isn't working even though the view only has one child
            // so it should be working according to the documentation.
            contentWidth: imageItem.width
            contentHeight: imageItem.height

            Item {
                id: imageItem
                // Scrollview doesn't care about scales, so to actually represent the scaled image we
                // need to explicitly tell the view the dimensions
                width: image.width * image.scale
                height: image.height * image.scale

                // These values are front/top half adjusted.
                // When scaling an image the scale viewport is the center of the image for unknown
                // reasons even when alignment is set to top-left. To bypass this shift the image
                // so the scaled x/y are actually painted where the 0,0 are expected.
                // Possibly to do with the relationship between sourceSize and the items size
                // and the items painted size.
                x: (width - image.width) / 2
                y: (height - image.height) / 2

                DropArea {
                    id: dropArea;
                    anchors.fill: parent;
                    onEntered: {
                        //                        drag.accept (Qt.CopyAction);
                        console.log("onEntered");
                        drag.accepted = false
                        console.debug(drag.urls)
                        console.debug(drag.urls.length)
                        console.debug(drag.urls[0])
                        if (drag.urls.length !== 1) {
                            return
                        }
                        if (!drag.urls[0].endsWith(".png")) {
                            return
                        }
                        drag.accepted = true
                        drag.action = Qt.CopyAction
                    }
                    onDropped: {
                        var png = path + ".png"
                        if (Needler.Application.copy(drop.urls[0], png)) {
                            load(png)
                        }
                    }
                }

                Image {
                    id: image
                    fillMode: Image.PreserveAspectFit
                    smooth: true


                    Menu {
                        id: imageContextMenu

                        MenuItem {
                            text: "add"

                            onTriggered: {
                                var select = selector.createObject()
                                select.x = mouseArea.lastX
                                select.y = mouseArea.lastY
                                selectorModel.append(select)
                            }
                        }

                        MenuItem {
                            text: "save"
                            onTriggered: { save() }
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent

                        property int lastX
                        property int lastY

                        onWheel: {
                            if (wheel.modifiers & Qt.ControlModifier) {
                                console.debug(wheel.angleDelta.y / 120)
                                image.scale = Math.max(1, image.scale + (wheel.angleDelta.y / 120 * 0.25));
                                wheel.accepted = true
                                return
                            }

                            wheel.accepted = false
                        }

                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPressed: {
                            lastX = mouse.x
                            lastY = mouse.y

                            if (mouse.button == Qt.RightButton) {
                                imageContextMenu.x = mouse.x
                                imageContextMenu.y = mouse.y
                                imageContextMenu.open()
                                mouse.accepted = true
                                return
                            }

                            mouse.accepted = false
                        }
                    }

                    ObjectModel {
                        id: selectorModel

                        property var properties: []
                        property var tags: []

                        function loadFromJSON(path) {
                            selectorModel.clear()
                            var xhr = new XMLHttpRequest;
                            xhr.open("GET", path);
                            xhr.onreadystatechange = function() {
                                if (xhr.readyState == XMLHttpRequest.DONE) {
                                    var a = JSON.parse(xhr.responseText);
                                    for (var i in a.area) {
                                        console.debug("area " + a.area[i])
                                        var select = selector.createObject()
                                        select.fromObject(a.area[i])

                                        if (i == a.area.length - 1) { // last
                                            select.clickArea = true
                                        }
                                        selectorModel.append(select)
                                    }

                                    selectorModel.properties = a.properties
                                    selectorModel.tags = a.tags
                                }
                            }
                            xhr.send();
                        }

                        function toJSON() {
                            var areas = []
                            console.debug("model count " + selectorModel.count)
                            var last = null
                            for (var i = 0; i < selectorModel.count; ++i) {
                                var selector = selectorModel.get(i)
                                if (selector.clickArea) {
                                    // openqa clicks the last area in the area array, so we'll
                                    // remember the intended click area and push it onto the array
                                    // once all others are in.
                                    last = selector.toObject()
                                    continue
                                }
                                areas.push(selector.toObject())
                            }
                            if (last !== null) {
                                areas.push(last)
                            }
                            var needle = {
                                area: areas,
                                properties: selectorModel.properties,
                                tags: selectorModel.tags
                            }
                            var json = JSON.stringify(needle, null, 2) + "\n"
                            console.debug(json)
                            return json
                        }

                        function removeObject(obj) {
                            for (var i = 0; i < selectorModel.count; ++i) {
                                if (selectorModel.get(i) === obj) {
                                    selectorModel.remove(i)
                                    return
                                }
                            }
                        }

                        // Sets all but the passed selector as not clickable and the passed one
                        // as clickable.
                        function setClickArea(obj) {
                            for (var i = 0; i < selectorModel.count; ++i) {
                                var item = selectorModel.get(i)
                                if (item === obj) {
                                    item.clickArea = true
                                } else {
                                    item.clickArea = false
                                }
                            }
                        }
                    }

                    Repeater {
                        model: selectorModel
                    }
                }
            }
        }
    }
}
