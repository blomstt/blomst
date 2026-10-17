import QtQuick
import QtQuick.Effects
import QtQml.Models

// Blomst login screen. Same wallpaper, colours, fonts and corner rounding as the desktop:
// colours come from theme.conf.user, which follows the wallpaper (see scripts/sddm_sync.sh).
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: surface

    readonly property color primary: config.primary || "#adc6ff"
    readonly property color accentText: config.onPrimary || "#102f60"
    readonly property color surface: config.surface || "#111318"
    readonly property color container: config.surfaceContainer || "#1e1f25"
    readonly property color containerHigh: config.surfaceContainerHigh || "#282a2f"
    readonly property color textColor: config.onSurface || "#e2e2e9"
    readonly property color textDim: config.onSurfaceVariant || "#c4c6d0"
    readonly property color outline: config.outline || "#8e9099"
    readonly property color errorColor: config.error || "#ffb4ab"
    readonly property string textFont: config.font || "Iosevka"
    readonly property string iconFont: config.iconFont || "Hurmit Nerd Font Mono"

    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property var currentUser: users.count > 0 ? users.objectAt(userIndex) : null
    readonly property var currentSession: sessions.count > 0 ? sessions.objectAt(sessionIndex) : null
    readonly property string userName: currentUser ? currentUser.userName : ""
    readonly property string displayName: currentUser ? currentUser.displayName : ""
    readonly property string sessionName: currentSession ? currentSession.sessionName : ""

    function login() {
        if (userName === "") return
        error.text = ""
        busy.running = true
        sddm.login(userName, password.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            busy.running = false
            password.text = ""
            error.text = "Wrong password, try again"
            shake.restart()
            password.forceActiveFocus()
        }
    }

    // The models have no get(), so make one object per user and session to read them from
    Instantiator {
        id: users
        model: userModel
        delegate: QtObject {
            required property string name
            required property string realName
            readonly property string userName: name
            readonly property string displayName: realName !== "" ? realName : name
        }
    }
    Instantiator {
        id: sessions
        model: sessionModel
        delegate: QtObject {
            required property string name
            readonly property string sessionName: name
        }
    }

    // ---------- background: the wallpaper, blurred and dimmed ----------
    Image {
        id: wallpaper
        anchors.fill: parent
        source: config.background || "background.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        blurEnabled: true
        blur: 0.8
        blurMax: 48
        autoPaddingEnabled: false
    }
    Rectangle { anchors.fill: parent; color: root.surface; opacity: 0.45 }

    // ---------- clock ----------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: card.top
        anchors.bottomMargin: parent.height * 0.08
        spacing: 2
        Text {
            id: time
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.textColor
            font.family: root.textFont
            font.pixelSize: Math.round(root.height * 0.11)
            font.bold: true
        }
        Text {
            id: date
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.textDim
            font.family: root.textFont
            font.pixelSize: Math.round(root.height * 0.022)
        }
        Timer {
            interval: 1000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: {
                var now = new Date()
                time.text = Qt.formatTime(now, "HH:mm")
                date.text = Qt.formatDate(now, "dddd d MMMM")
            }
        }
    }

    // ---------- login card ----------
    Rectangle {
        id: card
        width: 380
        height: cardColumn.implicitHeight + 48
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: parent.height * 0.08
        radius: 14
        color: Qt.rgba(root.container.r, root.container.g, root.container.b, 0.88)
        border.width: 1
        border.color: Qt.rgba(root.outline.r, root.outline.g, root.outline.b, 0.25)

        SequentialAnimation {
            id: shake
            loops: 2
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 10; duration: 45 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -10; duration: 90 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 0; duration: 45 }
        }

        Column {
            id: cardColumn
            x: 24; y: 24
            width: parent.width - 48
            spacing: 14

            // Avatar with the first letter, and arrows when there is more than one user
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18
                Text {
                    visible: userModel.count > 1
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰅁"
                    font.family: root.iconFont; font.pixelSize: 22
                    color: prevArea.containsMouse ? root.textColor : root.outline
                    MouseArea { id: prevArea; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.userIndex = (root.userIndex - 1 + userModel.count) % userModel.count }
                }
                Rectangle {
                    width: 84; height: 84; radius: 42
                    color: root.primary
                    Text {
                        anchors.centerIn: parent
                        text: root.displayName.charAt(0).toUpperCase()
                        color: root.accentText
                        font.family: root.textFont; font.pixelSize: 38; font.bold: true
                    }
                }
                Text {
                    visible: userModel.count > 1
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰅂"
                    font.family: root.iconFont; font.pixelSize: 22
                    color: nextArea.containsMouse ? root.textColor : root.outline
                    MouseArea { id: nextArea; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.userIndex = (root.userIndex + 1) % userModel.count }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.displayName
                color: root.textColor
                font.family: root.textFont; font.pixelSize: 20
            }

            // Password and the go button
            Rectangle {
                width: parent.width
                height: 48
                radius: 10
                color: root.containerHigh
                border.width: password.activeFocus ? 2 : 0
                border.color: error.text !== "" ? root.errorColor : root.primary
                TextInput {
                    id: password
                    anchors.left: parent.left; anchors.leftMargin: 16
                    anchors.right: go.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: root.textColor
                    selectionColor: root.primary
                    selectedTextColor: root.accentText
                    font.family: root.textFont; font.pixelSize: 16
                    focus: true
                    clip: true
                    onAccepted: root.login()
                    onTextChanged: if (text !== "") error.text = ""
                    Keys.onUpPressed: root.userIndex = (root.userIndex - 1 + userModel.count) % userModel.count
                    Keys.onDownPressed: root.userIndex = (root.userIndex + 1) % userModel.count
                }
                Text {
                    anchors.fill: password
                    verticalAlignment: Text.AlignVCenter
                    visible: password.text === ""
                    text: "Password"
                    color: root.outline
                    font.family: root.textFont; font.pixelSize: 16
                }
                Rectangle {
                    id: go
                    anchors.right: parent.right; anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 36; radius: 8
                    color: goArea.containsMouse ? Qt.lighter(root.primary, 1.1) : root.primary
                    Text {
                        anchors.centerIn: parent
                        text: busy.running ? "󰑓" : "󰁔"
                        font.family: root.iconFont; font.pixelSize: 18
                        color: root.accentText
                        RotationAnimation on rotation { id: busy; running: false; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                    }
                    MouseArea { id: goArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.login() }
                }
            }

            Text {
                id: error
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: text !== ""
                color: root.errorColor
                font.family: root.textFont; font.pixelSize: 14
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: keyboard.capsLock
                text: "Caps Lock is on"
                color: root.textDim
                font.family: root.textFont; font.pixelSize: 13
            }
        }
    }

    // ---------- bottom corners: session and power ----------
    component CornerButton: Rectangle {
        id: cb
        property string icon: ""
        property string label: ""
        signal clicked()
        width: cbRow.implicitWidth + 28
        height: 40
        radius: 10
        color: cbArea.containsMouse ? root.containerHigh : Qt.rgba(root.container.r, root.container.g, root.container.b, 0.75)
        Row {
            id: cbRow
            anchors.centerIn: parent
            spacing: 10
            Text { visible: cb.icon !== ""; text: cb.icon; font.family: root.iconFont; font.pixelSize: 17; color: root.textColor; anchors.verticalCenter: parent.verticalCenter }
            Text { visible: cb.label !== ""; text: cb.label; font.family: root.textFont; font.pixelSize: 14; color: root.textColor; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: cbArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cb.clicked() }
    }

    CornerButton {
        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 28
        visible: sessionModel.count > 0
        icon: "󰍹"
        label: root.sessionName + (sessionModel.count > 1 ? "   󰅀" : "")
        onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessionModel.count
    }
    Row {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 28
        spacing: 8
        CornerButton { visible: sddm.canSuspend; icon: "󰒲"; label: "Sleep"; onClicked: sddm.suspend() }
        CornerButton { visible: sddm.canReboot; icon: "󰜉"; label: "Restart"; onClicked: sddm.reboot() }
        CornerButton { visible: sddm.canPowerOff; icon: "󰐥"; label: "Shut down"; onClicked: sddm.powerOff() }
    }

    Component.onCompleted: password.forceActiveFocus()
}
