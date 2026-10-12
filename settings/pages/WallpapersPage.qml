import QtQuick
import "../components"

PageScroll {
    pageKey: "wallpapers"
    title: "Wallpapers"
    description: "Click one to apply it. Colours everywhere follow the wallpaper. New pictures dropped into ~/wallpapers show up here by themselves."

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
                Rectangle {
                    visible: tile.current
                    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10
                    width: currentText.implicitWidth + 16; height: 24; radius: 12
                    color: backend.palette.accent
                    Text { id: currentText; anchors.centerIn: parent; text: "Current"; color: backend.palette.accentText; font.pixelSize: 11 }
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
    Note {
        visible: backend.wallpapers.length === 0
        topPadding: 30
        horizontalAlignment: Text.AlignHCenter
        text: "No wallpapers found. Put .jpg or .png pictures in ~/wallpapers."
    }
}
