import QtQuick
import QtQuick.Window
import QtQuick.Layouts

// Blomst Settings. All data and file writing lives in the Python `backend` object.
// Colours come from backend.palette, which follows the wallpaper.
Window {
    id: root
    width: 1040
    height: 720
    minimumWidth: 820
    minimumHeight: 520
    visible: true
    title: "Blomst Settings"
    color: "transparent"

    property string page: "presets"

    // ---------- reusable pieces ----------

    component PillButton: Rectangle {
        id: pill
        property string label: ""
        property bool primary: false
        signal clicked()
        implicitWidth: pillText.implicitWidth + 32
        implicitHeight: 36
        radius: height / 2
        color: primary ? (pillArea.containsMouse ? Qt.lighter(backend.palette.surface3, 1.2) : backend.palette.surface3)
                       : (pillArea.containsMouse ? backend.palette.surface2 : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: backend.palette.text
            font.pixelSize: 14
        }
        MouseArea {
            id: pillArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component NavItem: Rectangle {
        id: nav
        property string label: ""
        property string key: ""
        property string current: ""
        readonly property bool active: current === key
        signal picked()
        width: parent ? parent.width : 200
        height: 44
        radius: 14
        color: active ? backend.palette.surface2 : (navArea.containsMouse ? backend.palette.surface : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            visible: nav.active
            width: 4; height: 18; radius: 2
            anchors.left: parent.left; anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: backend.palette.accent
        }
        Text {
            anchors.left: parent.left; anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            text: nav.label
            color: nav.active ? backend.palette.text : backend.palette.subtext
            font.pixelSize: 15
        }
        MouseArea {
            id: navArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.picked()
        }
    }

    component SectionTitle: Text {
        color: backend.palette.text
        font.pixelSize: 19
        topPadding: 14
        bottomPadding: 4
    }

    // One row of a settings page: title and hint on the left, a control on the right.
    component SettingRow: Rectangle {
        id: row
        property string title: ""
        property string hint: ""
        default property alias control: controlSlot.data
        width: parent ? parent.width : 600
        height: 64
        radius: 14
        color: backend.palette.surface
        Column {
            anchors.left: parent.left; anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text { text: row.title; color: backend.palette.text; font.pixelSize: 15 }
            Text { text: row.hint; visible: row.hint !== ""; color: backend.palette.subtext; font.pixelSize: 12 }
        }
        Item {
            id: controlSlot
            anchors.right: parent.right; anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 300
            height: 32
        }
    }

    // Slider bound to one backend setting. Writes when you let go.
    component SettingSlider: Item {
        id: slider
        property string key: ""
        property real from: 0
        property real to: 1
        property real step: 1
        property int decimals: 0
        property real value: 0
        readonly property real ratio: to > from ? (value - from) / (to - from) : 0
        anchors.fill: parent

        function sync() {
            var v = backend.settings[key]
            if (v !== undefined && !sliderArea.pressed)
                value = v
        }
        function setFromX(x) {
            var r = Math.max(0, Math.min(1, x / track.width))
            var v = Math.round((from + r * (to - from)) / step) * step
            value = Math.max(from, Math.min(to, v))
        }
        Component.onCompleted: sync()
        Connections {
            target: backend
            function onSettingsChanged() { slider.sync() }
        }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: valueText.left; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            radius: 3
            color: backend.palette.surface3
            Rectangle {
                width: track.width * slider.ratio
                height: parent.height
                radius: 3
                color: backend.palette.accent
            }
            Rectangle {
                x: track.width * slider.ratio - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16; radius: 8
                color: backend.palette.text
            }
        }
        Text {
            id: valueText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            horizontalAlignment: Text.AlignRight
            text: slider.value.toFixed(slider.decimals)
            color: backend.palette.subtext
            font.pixelSize: 13
        }
        MouseArea {
            id: sliderArea
            x: track.x
            width: track.width
            height: parent.height
            cursorShape: Qt.PointingHandCursor
            onPressed: (mouse) => slider.setFromX(mouse.x)
            onPositionChanged: (mouse) => { if (pressed) slider.setFromX(mouse.x) }
            onReleased: backend.setValue(slider.key, slider.value)
        }
    }

    // On/off switch bound to one backend setting.
    component SettingSwitch: Item {
        id: sw
        property string key: ""
        readonly property bool checked: backend.settings[key] === true
        anchors.fill: parent
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 50; height: 28; radius: 14
            color: sw.checked ? backend.palette.accent : backend.palette.surface3
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle {
                x: sw.checked ? parent.width - width - 4 : 4
                anchors.verticalCenter: parent.verticalCenter
                width: 20; height: 20; radius: 10
                color: sw.checked ? backend.palette.accentText : backend.palette.text
                Behavior on x { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: backend.setValue(sw.key, !sw.checked)
            }
        }
    }

    // A row of pills where one is selected. Not tied to the backend by itself.
    component Choice: Row {
        id: choice
        property var options: []
        property var current
        signal chosen(var value)
        spacing: 4
        Repeater {
            model: choice.options
            Rectangle {
                id: opt
                required property var modelData
                readonly property bool active: choice.current === modelData.value
                width: optText.implicitWidth + 24
                height: 32
                radius: 16
                color: active ? backend.palette.accent
                              : (optArea.containsMouse ? backend.palette.surface3 : backend.palette.surface2)
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    id: optText
                    anchors.centerIn: parent
                    text: opt.modelData.label
                    color: opt.active ? backend.palette.accentText : backend.palette.text
                    font.pixelSize: 13
                }
                MouseArea {
                    id: optArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: choice.chosen(opt.modelData.value)
                }
            }
        }
    }

    // Choice bound to one backend setting.
    component SettingChoice: Item {
        id: sc
        property string key: ""
        property var options: []
        anchors.fill: parent
        Choice {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            options: sc.options
            current: backend.settings[sc.key]
            onChosen: (value) => backend.setValue(sc.key, value)
        }
    }

    component Field: Rectangle {
        id: field
        property alias text: input.text
        property string placeholder: ""
        signal accepted()
        implicitWidth: 160
        implicitHeight: 40
        radius: 12
        color: backend.palette.surface2
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 14; anchors.rightMargin: 14
            verticalAlignment: TextInput.AlignVCenter
            color: backend.palette.text
            selectionColor: backend.palette.accent
            selectedTextColor: backend.palette.accentText
            font.pixelSize: 14
            clip: true
            selectByMouse: true
            onAccepted: field.accepted()
        }
        Text {
            anchors.fill: input
            verticalAlignment: Text.AlignVCenter
            visible: input.text === ""
            text: field.placeholder
            color: backend.palette.subtext
            font.pixelSize: 14
        }
    }

    // Scrollable page body. Put content in a Column inside it.
    component PageScroll: Flickable {
        id: scroll
        default property alias content: pageColumn.data
        anchors.fill: parent
        anchors.margins: 24
        contentWidth: width
        contentHeight: pageColumn.implicitHeight + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: pageColumn
            width: scroll.width
            spacing: 10
        }
    }

    // ---------- window ----------

    Rectangle {
        anchors.fill: parent
        color: backend.palette.window

        // Sidebar
        Rectangle {
            id: sidebar
            width: 230
            anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left
            color: backend.palette.sidebar

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 6

                Row {
                    spacing: 12
                    height: 64
                    Rectangle {
                        width: 48; height: 48; radius: 24
                        anchors.verticalCenter: parent.verticalCenter
                        color: backend.palette.accent
                        Text {
                            anchors.centerIn: parent
                            text: backend.userName.charAt(0).toUpperCase()
                            color: backend.palette.accentText
                            font.pixelSize: 20
                            font.bold: true
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: backend.userName; color: backend.palette.text; font.pixelSize: 16 }
                        Text { text: backend.hostName; color: backend.palette.subtext; font.pixelSize: 12 }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: backend.palette.surface2 }
                Item { width: 1; height: 6 }

                PillButton {
                    label: "Config folder"
                    primary: true
                    onClicked: backend.openConfigFolder()
                }

                Item { width: 1; height: 14 }

                NavItem { label: "Presets"; key: "presets"; current: root.page; onPicked: root.page = key }
                NavItem { label: "Wallpapers"; key: "wallpapers"; current: root.page; onPicked: root.page = key }
                NavItem { label: "Appearance"; key: "appearance"; current: root.page; onPicked: root.page = key }
                NavItem { label: "Animations"; key: "animations"; current: root.page; onPicked: root.page = key }
                NavItem { label: "Bar"; key: "bar"; current: root.page; onPicked: root.page = key }
                NavItem { label: "Idle"; key: "idle"; current: root.page; onPicked: root.page = key }
                NavItem { label: "Notifications"; key: "notifications"; current: root.page; onPicked: root.page = key }
                NavItem { label: "Apps"; key: "apps"; current: root.page; onPicked: { backend.refreshOpenApps(); root.page = key } }
            }
        }

        // Pages
        Item {
            anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.left: sidebar.right; anchors.right: parent.right

            // ----- Presets -----
            PageScroll {
                id: presetsPage
                visible: root.page === "presets"

                SectionTitle { text: "Presets" }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "A preset remembers the current wallpaper and every Appearance setting."
                    color: backend.palette.subtext
                    font.pixelSize: 13
                }

                Rectangle {
                    width: parent.width
                    height: 64
                    radius: 14
                    color: backend.palette.surface
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18; anchors.rightMargin: 12
                        spacing: 10
                        Text { text: "New"; color: backend.palette.text; font.pixelSize: 15 }
                        Field {
                            id: nameField
                            Layout.preferredWidth: 180
                            placeholder: "Name"
                            onAccepted: saveButton.clicked()
                        }
                        Field {
                            id: descField
                            Layout.fillWidth: true
                            placeholder: "Description (optional)"
                            onAccepted: saveButton.clicked()
                        }
                        PillButton {
                            id: saveButton
                            label: "Save current"
                            primary: true
                            onClicked: {
                                if (backend.savePreset(nameField.text, descField.text)) {
                                    nameField.text = ""
                                    descField.text = ""
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: backend.presets.length === 0
                    topPadding: 30
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "No presets yet. Set things up how you like, give it a name, and save."
                    color: backend.palette.subtext
                    font.pixelSize: 14
                }

                Flow {
                    id: presetFlow
                    width: parent.width
                    spacing: 14
                    readonly property real cardWidth: Math.floor((width - spacing) / 2)

                    Repeater {
                        model: backend.presets
                        Rectangle {
                            id: card
                            required property var modelData
                            width: presetFlow.cardWidth
                            height: cardColumn.implicitHeight
                            radius: 14
                            color: backend.palette.surface
                            clip: true
                            Column {
                                id: cardColumn
                                width: parent.width
                                Item {
                                    width: parent.width
                                    height: 60
                                    Rectangle {
                                        id: avatar
                                        x: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 36; height: 36; radius: 18
                                        color: backend.palette.surface3
                                        Text {
                                            anchors.centerIn: parent
                                            text: card.modelData.name.charAt(0).toUpperCase()
                                            color: backend.palette.text
                                            font.pixelSize: 15
                                        }
                                    }
                                    Column {
                                        anchors.left: avatar.right; anchors.leftMargin: 12
                                        anchors.right: parent.right; anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text {
                                            width: parent.width
                                            elide: Text.ElideRight
                                            text: card.modelData.name
                                            color: backend.palette.text
                                            font.pixelSize: 15
                                        }
                                        Text {
                                            width: parent.width
                                            elide: Text.ElideRight
                                            text: card.modelData.description !== "" ? card.modelData.description : "Saved preset"
                                            color: backend.palette.subtext
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                                Rectangle {
                                    width: parent.width
                                    height: Math.round(width * 0.44)
                                    color: backend.palette.surface2
                                    Image {
                                        anchors.fill: parent
                                        source: card.modelData.image
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        sourceSize.width: 600
                                        clip: true
                                    }
                                }
                                Item {
                                    width: parent.width
                                    height: 56
                                    Row {
                                        anchors.right: parent.right; anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        PillButton { label: "Remove"; onClicked: backend.removePreset(card.modelData.name) }
                                        PillButton { label: "Apply"; primary: true; onClicked: backend.applyPreset(card.modelData.name) }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ----- Wallpapers -----
            PageScroll {
                id: wallpapersPage
                visible: root.page === "wallpapers"

                SectionTitle { text: "Wallpapers" }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Click one to apply it. Colours everywhere follow the wallpaper."
                    color: backend.palette.subtext
                    font.pixelSize: 13
                }

                Flow {
                    id: wallFlow
                    width: parent.width
                    spacing: 12
                    readonly property real tileWidth: Math.floor((width - 2 * spacing) / 3)

                    Repeater {
                        model: backend.wallpapers
                        Rectangle {
                            id: tile
                            required property var modelData
                            readonly property bool current: backend.currentWallpaper === modelData.name
                            width: wallFlow.tileWidth
                            height: Math.round(width * 0.58)
                            radius: 12
                            color: current ? backend.palette.accent : (tileArea.containsMouse ? backend.palette.surface3 : backend.palette.surface)
                            Image {
                                anchors.fill: parent
                                anchors.margins: 3
                                source: tile.modelData.image
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 400
                                clip: true
                            }
                            MouseArea {
                                id: tileArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.applyWallpaper(tile.modelData.name)
                            }
                        }
                    }
                }
            }

            // ----- Appearance -----
            PageScroll {
                id: appearancePage
                visible: root.page === "appearance"

                SectionTitle { text: "Windows" }
                SettingRow {
                    title: "Gaps between windows"
                    SettingSlider { key: "gaps_in"; from: 0; to: 20 }
                }
                SettingRow {
                    title: "Gaps at screen edges"
                    SettingSlider { key: "gaps_out"; from: 0; to: 40 }
                }
                SettingRow {
                    title: "Corner rounding"
                    SettingSlider { key: "rounding"; from: 0; to: 30 }
                }
                SettingRow {
                    title: "Border thickness"
                    hint: "0 hides the border"
                    SettingSlider { key: "border_size"; from: 0; to: 6 }
                }
                SettingRow {
                    title: "Unfocused window opacity"
                    SettingSlider { key: "inactive_opacity"; from: 0.5; to: 1; step: 0.01; decimals: 2 }
                }

                SectionTitle { text: "Floating windows" }
                SettingRow {
                    title: "Remember size"
                    hint: "Floating windows reopen at the size you last gave them"
                    SettingSwitch { key: "float_size" }
                }
                SettingRow {
                    title: "Remember position"
                    hint: "Floating windows reopen where you last put them"
                    SettingSwitch { key: "float_position" }
                }

                SectionTitle { text: "Blur and shadow" }
                SettingRow {
                    title: "Blur"
                    hint: "Blurs whatever is behind see-through windows"
                    SettingSwitch { key: "blur_enabled" }
                }
                SettingRow {
                    title: "Blur strength"
                    SettingSlider { key: "blur_size"; from: 1; to: 15 }
                }
                SettingRow {
                    title: "Blur passes"
                    hint: "More is smoother and costs a little more GPU"
                    SettingSlider { key: "blur_passes"; from: 1; to: 5 }
                }
                SettingRow {
                    title: "Shadows"
                    SettingSwitch { key: "shadow_enabled" }
                }

                SectionTitle { text: "Terminal" }
                SettingRow {
                    title: "Terminal opacity"
                    hint: "Open terminals may need reopening"
                    SettingSlider { key: "terminal_opacity"; from: 0.3; to: 1; step: 0.01; decimals: 2 }
                }
            }

            // ----- Animations -----
            PageScroll {
                id: animationsPage
                visible: root.page === "animations"

                SectionTitle { text: "Animations" }
                SettingRow {
                    title: "Animations"
                    hint: "Turn off for the snappiest feel"
                    SettingSwitch { key: "animations_enabled" }
                }
                SettingRow {
                    title: "Speed"
                    hint: "How long windows, popups and fades take"
                    SettingChoice {
                        key: "anim_speed"
                        options: [
                            { value: "fast", label: "Fast" },
                            { value: "normal", label: "Normal" },
                            { value: "slow", label: "Slow" }
                        ]
                    }
                }
                SettingRow {
                    title: "Workspace switch"
                    hint: "How the screen moves when you change workspace"
                    SettingChoice {
                        key: "ws_anim"
                        options: [
                            { value: "vertical", label: "Up/down" },
                            { value: "horizontal", label: "Sideways" },
                            { value: "fade", label: "Fade" }
                        ]
                    }
                }
                SettingRow {
                    title: "Rotating border"
                    hint: "The gradient on the focused window slowly spins"
                    SettingSwitch { key: "border_spin" }
                }
            }

            // ----- Bar -----
            PageScroll {
                id: barPage
                visible: root.page === "bar"

                SectionTitle { text: "Side-bar" }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Choose what the side-bar shows. The bar reloads by itself after a change."
                    color: backend.palette.subtext
                    font.pixelSize: 13
                }
                SettingRow { title: "CPU ring"; SettingSwitch { key: "show_cpu" } }
                SettingRow { title: "Temperature ring"; SettingSwitch { key: "show_temp" } }
                SettingRow { title: "Memory ring"; SettingSwitch { key: "show_mem" } }
                SettingRow { title: "Disk ring"; SettingSwitch { key: "show_disk" } }
                SettingRow {
                    title: "Music"
                    hint: "Song title, cover and seek bar in the middle of the bar"
                    SettingSwitch { key: "show_music" }
                }
            }

            // ----- Idle -----
            PageScroll {
                id: idlePage
                visible: root.page === "idle"

                SectionTitle { text: "When you step away" }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "These apply while idle is enabled (the eye icon in the bar). Times are in minutes without touching the mouse or keyboard."
                    color: backend.palette.subtext
                    font.pixelSize: 13
                }
                SettingRow {
                    title: "Lock the screen after"
                    hint: "Minutes"
                    SettingSlider { key: "idle_lock_min"; from: 1; to: 120 }
                }
                SettingRow {
                    title: "Suspend the PC after"
                    hint: "Minutes"
                    SettingSlider { key: "idle_suspend_min"; from: 5; to: 240; step: 5 }
                }
            }

            // ----- Notifications -----
            PageScroll {
                id: notificationsPage
                visible: root.page === "notifications"

                SectionTitle { text: "Pop-ups" }
                SettingRow {
                    title: "Show pop-ups"
                    hint: "Off is do not disturb: notifications still land in the notification center"
                    SettingSwitch { key: "notif_popups" }
                }
                SettingRow {
                    title: "Pop-ups stay for"
                    hint: "Seconds"
                    SettingSlider { key: "notif_popup_seconds"; from: 3; to: 30 }
                }

                SectionTitle { text: "Notification center" }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "The list under the calendar in the Super + H widgets."
                    color: backend.palette.subtext
                    font.pixelSize: 13
                }
                SettingRow {
                    title: "Show with Super + H"
                    SettingSwitch { key: "notif_in_stack" }
                }
                SettingRow {
                    title: "Hide pop-ups while it's open"
                    hint: "They would cover the widgets otherwise"
                    SettingSwitch { key: "notif_hide_with_stack" }
                }
                SettingRow {
                    title: "Keep the last"
                    hint: "Notifications in the history"
                    SettingSlider { key: "notif_history_limit"; from: 10; to: 200; step: 10 }
                }
                SettingRow {
                    title: "Clear history"
                    hint: "Removes everything from the notification center"
                    PillButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Clear"
                        onClicked: backend.clearNotifications()
                    }
                }
            }

            // ----- Apps -----
            PageScroll {
                id: appsPage
                visible: root.page === "apps"
                property string newScreen: "main"
                property int newWorkspace: 1
                property bool newFloating: false

                SectionTitle { text: "Default apps" }
                Rectangle {
                    width: parent.width
                    height: browserColumn.implicitHeight + 28
                    radius: 14
                    color: backend.palette.surface
                    Column {
                        id: browserColumn
                        x: 18; y: 14
                        width: parent.width - 36
                        spacing: 12
                        Column {
                            spacing: 2
                            Text { text: "Browser"; color: backend.palette.text; font.pixelSize: 15 }
                            Text { text: "Opens with Super + B"; color: backend.palette.subtext; font.pixelSize: 12 }
                        }
                        Flow {
                            width: parent.width
                            spacing: 6
                            Choice {
                                options: backend.browsers
                                current: backend.settings.browser
                                onChosen: (value) => backend.setValue("browser", value)
                            }
                        }
                        RowLayout {
                            width: parent.width
                            spacing: 10
                            Field {
                                id: browserField
                                Layout.fillWidth: true
                                placeholder: "Or type another command"
                                onAccepted: browserSet.clicked()
                            }
                            PillButton {
                                id: browserSet
                                label: "Set"
                                primary: true
                                onClicked: {
                                    if (browserField.text.trim() !== "") {
                                        backend.setValue("browser", browserField.text.trim())
                                        browserField.text = ""
                                    }
                                }
                            }
                        }
                    }
                }

                SectionTitle { text: "Where apps open" }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Choose where an app opens, whether it opens floating instead of filling the screen, or both. Applies to windows opened from now on."
                    color: backend.palette.subtext
                    font.pixelSize: 13
                }

                Rectangle {
                    width: parent.width
                    height: addColumn.implicitHeight + 28
                    radius: 14
                    color: backend.palette.surface
                    Column {
                        id: addColumn
                        x: 18; y: 14
                        width: parent.width - 36
                        spacing: 12

                        Text { text: "Open right now (click to pick)"; color: backend.palette.subtext; font.pixelSize: 12 }
                        Flow {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: backend.openApps
                                PillButton {
                                    required property var modelData
                                    label: modelData
                                    primary: true
                                    onClicked: classField.text = modelData
                                }
                            }
                            Text {
                                visible: backend.openApps.length === 0
                                text: "Nothing found. Type the app's window class below."
                                color: backend.palette.subtext
                                font.pixelSize: 13
                            }
                        }

                        RowLayout {
                            width: parent.width
                            spacing: 10
                            Field {
                                id: classField
                                Layout.fillWidth: true
                                placeholder: "App (window class)"
                            }
                            PillButton {
                                label: "Save"
                                primary: true
                                onClicked: {
                                    if (backend.addAppRule(classField.text, appsPage.newScreen, appsPage.newWorkspace, appsPage.newFloating))
                                        classField.text = ""
                                }
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: 14
                            Choice {
                                options: [ { value: false, label: "Tiled" }, { value: true, label: "Floating" } ]
                                current: appsPage.newFloating
                                onChosen: (value) => appsPage.newFloating = value
                            }
                            Choice {
                                options: [ { value: "any", label: "Any screen" }, { value: "main", label: "Main" }, { value: "second", label: "Second" } ]
                                current: appsPage.newScreen
                                onChosen: (value) => appsPage.newScreen = value
                            }
                            Choice {
                                opacity: appsPage.newScreen === "any" ? 0.35 : 1
                                options: [ { value: 1, label: "1" }, { value: 2, label: "2" }, { value: 3, label: "3" },
                                           { value: 4, label: "4" }, { value: 5, label: "5" } ]
                                current: appsPage.newWorkspace
                                onChosen: (value) => appsPage.newWorkspace = value
                            }
                        }
                        Text {
                            visible: appsPage.newScreen === "any" && !appsPage.newFloating
                            text: "Pick Floating, a screen, or both. Tiled on any screen is how apps already open."
                            color: backend.palette.subtext
                            font.pixelSize: 12
                        }
                    }
                }

                Text {
                    visible: backend.appRules.length === 0
                    topPadding: 24
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "No app rules yet."
                    color: backend.palette.subtext
                    font.pixelSize: 14
                }

                Repeater {
                    model: backend.appRules
                    SettingRow {
                        id: ruleRow
                        required property var modelData
                        title: modelData["class"]
                        hint: (modelData.floating ? "Floating" : "Tiled")
                              + (modelData.screen === "any" ? ", wherever you are"
                                 : (modelData.screen === "second" ? ", second screen" : ", main screen") + ", workspace " + modelData.workspace)
                        PillButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            label: "Remove"
                            onClicked: backend.removeAppRule(ruleRow.modelData["class"])
                        }
                    }
                }
            }
        }
    }
}
