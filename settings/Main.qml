import QtQuick
import QtQuick.Window
import "components"
import "pages"

// Blomst Settings. All data and file writing lives in the Python `backend` object.
// Colours come from backend.palette, which follows the wallpaper.
// Pieces live in components/, one file per page in pages/.
Window {
    id: root
    width: 1080
    height: 760
    minimumWidth: 860
    minimumHeight: 540
    visible: true
    title: "Blomst Settings"
    color: "transparent"

    // ---------- keyboard ----------
    Shortcut { sequence: "Ctrl+F"; onActivated: searchField.focusInput() }
    Shortcut { sequence: "Ctrl+K"; onActivated: searchField.focusInput() }
    Shortcut { sequence: "Ctrl+Z"; enabled: backend.canUndo; onActivated: backend.undo() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: root.close() }
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (backend.monitorPending) backend.revertMonitors()
            else if (Ui.query !== "") { searchField.text = ""; contentArea.forceActiveFocus() }
            else root.close()
        }
    }
    Shortcut { sequence: "Ctrl+PgDown"; onActivated: root.stepPage(1) }
    Shortcut { sequence: "Ctrl+PgUp"; onActivated: root.stepPage(-1) }
    function stepPage(delta) {
        var i = 0
        for (; i < Ui.pages.length; i++) if (Ui.pages[i].key === Ui.page) break
        Ui.query = ""
        Ui.page = Ui.pages[(i + delta + Ui.pages.length) % Ui.pages.length].key
    }

    Rectangle {
        anchors.fill: parent
        color: backend.palette.window

        // ---------- sidebar ----------
        Rectangle {
            id: sidebar
            width: 240
            anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left
            color: backend.palette.sidebar

            Row {
                id: userRow
                x: 18; y: 18
                spacing: 12
                height: 48
                Rectangle {
                    width: 44; height: 44; radius: 22
                    anchors.verticalCenter: parent.verticalCenter
                    color: backend.palette.accent
                    Text {
                        anchors.centerIn: parent
                        text: backend.userName.charAt(0).toUpperCase()
                        color: backend.palette.accentText
                        font.pixelSize: 19
                        font.bold: true
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: backend.userName; color: backend.palette.text; font.pixelSize: 15 }
                    Text { text: backend.hostName; color: backend.palette.subtext; font.pixelSize: 12 }
                }
            }

            Field {
                id: searchField
                x: 14
                anchors.top: userRow.bottom; anchors.topMargin: 16
                width: parent.width - 28
                icon: ""
                placeholder: "Search   Ctrl+F"
                onTextChanged: Ui.query = text
                onAccepted: {
                    var results = Ui.search(text)
                    if (results.length) searchList.open(results[0])
                }
                Connections {
                    target: Ui
                    function onQueryChanged() { if (Ui.query === "" && searchField.text !== "") searchField.text = "" }
                }
            }

            Flickable {
                anchors.top: searchField.bottom; anchors.topMargin: 12
                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 14; anchors.rightMargin: 14
                contentHeight: navColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: navColumn
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: Ui.pages
                        Column {
                            required property var modelData
                            required property int index
                            width: navColumn.width
                            Text {
                                visible: modelData.group !== "" && (index === 0 || Ui.pages[index - 1].group !== modelData.group)
                                text: modelData.group.toUpperCase()
                                color: backend.palette.subtext
                                font.pixelSize: 11
                                font.letterSpacing: 1.2
                                leftPadding: 18
                                topPadding: 14
                                bottomPadding: 6
                            }
                            NavItem { label: modelData.label; key: modelData.key; icon: modelData.icon }
                        }
                    }
                }
            }
        }

        // ---------- pages ----------
        Item {
            id: contentArea
            anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.left: sidebar.right; anchors.right: parent.right
            focus: true
            // Clicking empty space leaves any text box
            TapHandler { onTapped: contentArea.forceActiveFocus() }

            HomePage {}
            WallpapersPage {}
            PresetsPage {}
            AppearancePage {}
            FontsPage {}
            AnimationsPage {}
            BarPage {}
            NotificationsPage {}
            DisplaysPage {}
            InputPage {}
            KeybindsPage {}
            AppsPage {}
            StartupPage {}
            IdlePage {}

            // ----- search results -----
            Flickable {
                id: searchList
                visible: Ui.query !== ""
                anchors.fill: parent
                anchors.margins: 28
                contentHeight: resultsColumn.implicitHeight + 24
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                readonly property var results: Ui.search(Ui.query)

                function open(r) {
                    contentArea.forceActiveFocus()      // so Ctrl+Z undoes settings, not search text
                    if (r.kind === "row") Ui.show(r.row)
                    else if (r.kind === "bind") { Ui.keybindFilter = r.title; Ui.query = ""; Ui.page = "keybinds" }
                    else { Ui.query = ""; Ui.page = r.page }
                }

                Column {
                    id: resultsColumn
                    width: parent.width
                    spacing: 8
                    Text { text: "Search"; color: backend.palette.text; font.pixelSize: 26; bottomPadding: 6 }
                    Text {
                        visible: searchList.results.length === 0
                        text: "Nothing matches “" + Ui.query + "”."
                        color: backend.palette.subtext
                        font.pixelSize: 14
                    }
                    Repeater {
                        model: searchList.results
                        Rectangle {
                            id: result
                            required property var modelData
                            required property int index
                            width: resultsColumn.width
                            height: 58
                            radius: 14
                            color: resultArea.containsMouse || (index === 0 && searchField.input.activeFocus)
                                   ? backend.palette.surface2 : backend.palette.surface
                            Icon {
                                id: resultIcon
                                x: 18; anchors.verticalCenter: parent.verticalCenter
                                width: Ui.hasIcons ? 18 : 0
                                glyph: result.modelData.kind === "page" ? "" : (result.modelData.kind === "bind" ? "" : "")
                            }
                            Column {
                                anchors.left: resultIcon.right; anchors.leftMargin: Ui.hasIcons ? 14 : 0
                                anchors.right: parent.right; anchors.rightMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text { width: parent.width; elide: Text.ElideRight; text: result.modelData.title; color: backend.palette.text; font.pixelSize: 15 }
                                Text { width: parent.width; elide: Text.ElideRight; text: result.modelData.detail; color: backend.palette.subtext; font.pixelSize: 12 }
                            }
                            MouseArea {
                                id: resultArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchList.open(result.modelData)
                            }
                        }
                    }
                }
            }

            // ----- display change waiting for confirmation -----
            Rectangle {
                id: monitorBanner
                visible: backend.monitorPending
                anchors.top: parent.top; anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                width: bannerRow.implicitWidth + 32
                height: 60
                radius: 18
                color: backend.palette.surface3
                z: 10
                Row {
                    id: bannerRow
                    anchors.centerIn: parent
                    spacing: 14
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Keep this display setting? Going back in " + backend.monitorCountdown + " s"
                        color: backend.palette.text
                        font.pixelSize: 14
                    }
                    PillButton { label: "Keep"; primary: true; onClicked: backend.keepMonitors() }
                    PillButton { label: "Go back"; onClicked: backend.revertMonitors() }
                }
            }

            // ----- saved / undo message -----
            Rectangle {
                id: toast
                property string message: ""
                property bool canUndo: false
                property bool error: false
                property bool shown: false
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: shown ? 22 : -height - 10
                Behavior on anchors.bottomMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                width: toastRow.implicitWidth + 28
                height: 48
                radius: 24
                color: backend.palette.surface3
                border.width: error ? 1 : 0
                border.color: Ui.danger
                z: 10

                function show(text, undoable, isError) {
                    message = text; canUndo = undoable; error = isError
                    shown = true
                    hideTimer.restart()
                }
                Timer { id: hideTimer; interval: 4000; onTriggered: toast.shown = false }

                Row {
                    id: toastRow
                    anchors.centerIn: parent
                    spacing: 10
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: toast.error ? "" : ""
                        color: toast.error ? Ui.danger : backend.palette.accent
                        visible: Ui.hasIcons
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: toast.message
                        color: backend.palette.text
                        font.pixelSize: 14
                    }
                    PillButton {
                        visible: toast.canUndo
                        anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: 32
                        label: "Undo"
                        icon: ""
                        onClicked: backend.undo()
                    }
                }
            }
            Connections {
                target: backend
                function onSaved(key) {
                    if (key === "monitor") toast.show("Display setting kept", false, false)
                    else toast.show("Saved: " + Ui.titleFor(key), true, false)
                }
                function onUndone(key) {
                    toast.show(key === "monitor" ? "Display setting reverted" : "Undone: " + Ui.titleFor(key), backend.canUndo, false)
                }
                function onFailed(key, reason) {
                    toast.show(reason + (key === "monitor" ? "" : ": " + Ui.titleFor(key)), false, true)
                }
            }
        }
    }
}
