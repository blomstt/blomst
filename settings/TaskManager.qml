import QtQuick
import QtQuick.Window
import "components"

// Task manager (Ctrl + Shift + Esc). Data comes from the Python `tasks` object,
// colours from backend.palette like the settings window.
// Rows are sorted into plain-language sections (see tasks.py) so it is clear what is safe to end.
Window {
    id: root
    width: 820
    height: 680
    minimumWidth: 600
    minimumHeight: 420
    visible: true
    title: "Task Manager"
    color: "transparent"

    property string filter: ""
    property bool showDesktop: false
    readonly property bool searching: filter.trim() !== ""
    readonly property var shown: tasks.rows.filter(function(r) {
        var q = root.filter.trim().toLowerCase()
        return q === "" || (r.name + " " + r.title + " " + r.about).toLowerCase().indexOf(q) >= 0
    })
    function section(name) { return shown.filter(function(r) { return r.section === name }) }
    readonly property var apps: section("app")
    readonly property var backgroundApps: section("background")
    readonly property var others: section("other")
    readonly property var desktop: section("desktop")

    function size(bytes) {
        if (bytes >= 1e9) return (bytes / 1e9).toFixed(1) + " GB"
        return Math.round(bytes / 1e6) + " MB"
    }
    function total(rows) {
        var sum = 0
        for (var i = 0; i < rows.length; i++) sum += rows[i].memory
        return sum
    }

    // A section title, a line saying what is in it, and column labels
    component Section: Item {
        id: section
        property string text: ""
        property string note: ""
        property bool collapsible: false
        property bool open: true
        signal toggled()
        width: parent ? parent.width - 8 : 600
        height: note !== "" ? 62 : 42
        Row {
            id: titleRow
            anchors.top: parent.top; anchors.topMargin: 12
            spacing: 8
            Icon {
                visible: section.collapsible
                glyph: section.open ? "" : ""
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
            Text { text: section.text; color: backend.palette.text; font.pixelSize: 16 }
        }
        MouseArea {
            visible: section.collapsible
            anchors.fill: titleRow
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: section.toggled()
        }
        Text {
            visible: section.note !== ""
            anchors.top: titleRow.bottom; anchors.topMargin: 3
            anchors.left: parent.left; anchors.right: columns.left; anchors.rightMargin: 12
            elide: Text.ElideRight
            text: section.note
            color: backend.palette.subtext
            font.pixelSize: 12
        }
        Row {
            id: columns
            visible: section.open
            anchors.right: parent.right; anchors.rightMargin: 152
            anchors.bottom: parent.bottom; anchors.bottomMargin: 6
            spacing: 8
            Text { width: 70; horizontalAlignment: Text.AlignRight; text: "CPU"; color: backend.palette.subtext; font.pixelSize: 11 }
            Text { width: 84; horizontalAlignment: Text.AlignRight; text: "Memory"; color: backend.palette.subtext; font.pixelSize: 11 }
        }
    }

    component TaskRow: Rectangle {
        id: row
        required property var modelData
        property bool armed: false            // desktop parts need a second click
        readonly property bool careful: modelData.safety === "caution"
        width: parent ? parent.width - 8 : 600
        height: 56
        radius: 12
        color: rowArea.containsMouse ? backend.palette.surface2 : backend.palette.surface
        border.width: armed ? 1 : 0
        border.color: Ui.danger
        Behavior on color { ColorAnimation { duration: 100 } }
        MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
        Timer { id: disarm; interval: 5000; onTriggered: row.armed = false }

        Item {
            id: iconBox
            x: 14; width: 30; height: 30
            anchors.verticalCenter: parent.verticalCenter
            Image {
                anchors.fill: parent
                visible: row.modelData.kind === "app"
                source: visible ? "image://icon/" + row.modelData.icon : ""
                sourceSize: Qt.size(60, 60)
                smooth: true
                asynchronous: true
            }
            Icon {
                anchors.centerIn: parent
                visible: row.modelData.kind !== "app"
                glyph: row.modelData.protected ? "" : (row.modelData.section === "desktop" ? "" : "")
                font.pixelSize: 15
            }
        }
        Column {
            anchors.left: iconBox.right; anchors.leftMargin: 14
            anchors.right: cpuText.left; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Row {
                width: parent.width
                spacing: 8
                Text {
                    id: nameText
                    width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + 8 : 0))
                    elide: Text.ElideRight
                    text: row.modelData.name
                    color: backend.palette.text
                    font.pixelSize: 15
                }
                Rectangle {
                    id: badge
                    visible: row.modelData.section === "background"
                    anchors.verticalCenter: nameText.verticalCenter
                    width: badgeText.implicitWidth + 14; height: 18; radius: 9
                    color: backend.palette.surface3
                    Text { id: badgeText; anchors.centerIn: parent; text: "No window"; color: backend.palette.text; font.pixelSize: 10 }
                }
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                readonly property var parts: [
                    row.modelData.section === "app" && row.modelData.title !== row.modelData.name ? row.modelData.title : row.modelData.about,
                    row.modelData.section === "other" && !row.modelData.about ? row.modelData.title : "",
                    row.modelData.windows > 1 ? row.modelData.windows + " windows" : "",
                    row.modelData.count > 1 ? row.modelData.count + " processes" : ""
                ].filter(function(s) { return s })
                text: row.modelData.stuck ? "Not closing. Force kill stops it at once (unsaved work is lost)"
                      : row.armed ? "If you end it: " + row.modelData.consequence
                      : parts.join(" · ")
                color: row.modelData.stuck || row.armed ? Ui.danger : backend.palette.subtext
                font.pixelSize: 12
            }
        }
        Text {
            id: cpuText
            anchors.right: memText.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 70
            horizontalAlignment: Text.AlignRight
            text: row.modelData.cpu.toFixed(1) + "%"
            color: row.modelData.cpu >= 25 ? backend.palette.text : backend.palette.subtext
            font.pixelSize: 13
            font.bold: row.modelData.cpu >= 25
        }
        Text {
            id: memText
            anchors.right: actions.left; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 84
            horizontalAlignment: Text.AlignRight
            text: row.modelData.memory >= 1e9 ? (row.modelData.memory / 1e9).toFixed(1) + " GB" : Math.round(row.modelData.memory / 1e6) + " MB"
            color: row.modelData.memory >= 1e9 ? backend.palette.text : backend.palette.subtext
            font.pixelSize: 13
            font.bold: row.modelData.memory >= 1e9
        }
        Item {
            id: actions
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 128; height: 36
            Text {
                visible: row.modelData.protected
                anchors.right: parent.right; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "Leave running"
                color: backend.palette.subtext
                font.pixelSize: 12
            }
            PillButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !row.modelData.protected
                label: row.modelData.stuck ? "Force kill" : (row.armed ? "End anyway" : "End task")
                icon: row.modelData.stuck ? "" : ""
                danger: row.modelData.stuck || row.armed || rowArea.containsMouse
                primary: row.modelData.stuck || row.armed
                onClicked: {
                    if (row.modelData.stuck) tasks.forceKill(row.modelData.key)
                    else if (row.careful && !row.armed) { row.armed = true; disarm.restart() }
                    else { row.armed = false; tasks.endTask(row.modelData.key) }
                }
            }
        }
    }

    Shortcut { sequence: "Ctrl+F"; onActivated: searchField.focusInput() }
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (searchField.text !== "") searchField.text = ""
            else root.close()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: backend.palette.window

        // ---------- header ----------
        Column {
            id: header
            x: 24; y: 22
            width: parent.width - 48
            spacing: 14

            Row {
                width: parent.width
                Text {
                    width: parent.width - stats.width
                    text: "Task manager"
                    color: backend.palette.text
                    font.pixelSize: 26
                }
                Row {
                    id: stats
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: [
                            { label: "CPU", value: tasks.cpu.toFixed(0) + "%", ratio: tasks.cpu / 100 },
                            { label: "Memory", value: root.size(tasks.memoryUsed) + " / " + root.size(tasks.memoryTotal), ratio: tasks.memoryUsed / tasks.memoryTotal },
                            { label: "Processes", value: String(tasks.processes), ratio: 0 }
                        ]
                        Rectangle {
                            required property var modelData
                            width: statColumn.implicitWidth + 28
                            height: 48
                            radius: 12
                            color: backend.palette.surface
                            clip: true
                            Rectangle {
                                anchors.left: parent.left; anchors.bottom: parent.bottom
                                height: 3
                                width: parent.width * Math.min(1, modelData.ratio)
                                color: backend.palette.accent
                                Behavior on width { NumberAnimation { duration: 400 } }
                            }
                            Column {
                                id: statColumn
                                anchors.centerIn: parent
                                Text { text: modelData.label; color: backend.palette.subtext; font.pixelSize: 11 }
                                Text { text: modelData.value; color: backend.palette.text; font.pixelSize: 15 }
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 10
                Field {
                    id: searchField
                    width: parent.width - sortChoice.width - 10
                    icon: ""
                    placeholder: "Search apps and processes   Ctrl+F"
                    onTextChanged: root.filter = text
                }
                Choice {
                    id: sortChoice
                    anchors.verticalCenter: parent.verticalCenter
                    options: [ { value: "cpu", label: "CPU" }, { value: "memory", label: "Memory" }, { value: "name", label: "Name" } ]
                    current: tasks.sortBy
                    onChosen: (value) => tasks.sortBy = value
                }
            }
        }

        // ---------- list ----------
        Flickable {
            id: list
            anchors.top: header.bottom; anchors.topMargin: 8
            anchors.bottom: parent.bottom; anchors.bottomMargin: 12
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 24; anchors.rightMargin: 16
            contentHeight: listColumn.implicitHeight + 60
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // Rows stay put while the mouse is over the list, so a click hits what you aimed at
            HoverHandler { onHoveredChanged: tasks.frozen = hovered }

            Column {
                id: listColumn
                width: parent.width
                spacing: 6

                Section { text: "Apps  (" + root.apps.length + ")"; note: "Open windows" }
                Repeater { model: root.apps; TaskRow {} }
                Text {
                    visible: root.apps.length === 0
                    text: root.searching ? "No open app matches." : "No open windows."
                    color: backend.palette.subtext
                    font.pixelSize: 13
                }

                Section {
                    visible: root.backgroundApps.length > 0
                    text: "Running in the background  (" + root.backgroundApps.length + ")"
                    note: "Open but without a window, using " + root.size(root.total(root.backgroundApps)) + ". Safe to end if you are not using them"
                }
                Repeater { model: root.backgroundApps; TaskRow {} }

                Section {
                    visible: root.others.length > 0
                    text: "Other processes  (" + root.others.length + ")"
                    note: "Small helpers. Fine to leave running, and safe to end"
                }
                Repeater { model: root.others; TaskRow {} }

                Section {
                    visible: root.desktop.length > 0
                    text: "Your desktop  (" + root.desktop.length + ")"
                    note: "What your desktop is made of. Leave these alone unless something is stuck"
                    collapsible: !root.searching
                    open: root.showDesktop || root.searching
                    onToggled: root.showDesktop = !root.showDesktop
                }
                Repeater { model: root.showDesktop || root.searching ? root.desktop : []; TaskRow {} }
            }
        }

        // Scroll position
        Rectangle {
            visible: list.visibleArea.heightRatio < 1
            x: root.width - 10
            y: list.y + list.visibleArea.yPosition * list.height
            width: 4; radius: 2
            height: list.visibleArea.heightRatio * list.height
            color: backend.palette.surface3
            opacity: 0.6
        }

        // ---------- message ----------
        Rectangle {
            id: toast
            property string message: ""
            property bool error: false
            property bool shown: false
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: shown ? 22 : -height - 10
            Behavior on anchors.bottomMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            width: toastText.implicitWidth + 40
            height: 44
            radius: 22
            color: backend.palette.surface3
            border.width: error ? 1 : 0
            border.color: Ui.danger
            Text { id: toastText; anchors.centerIn: parent; text: toast.message; color: backend.palette.text; font.pixelSize: 14 }
            Timer { id: hideTimer; interval: 4000; onTriggered: toast.shown = false }
            Connections {
                target: tasks
                function onEnded(name, stillRunning) {
                    toast.message = stillRunning ? name + " is not closing. Use Force kill." : name + " ended"
                    toast.error = stillRunning
                    toast.shown = true
                    hideTimer.restart()
                }
            }
        }
    }
}
