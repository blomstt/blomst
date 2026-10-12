import QtQuick

// One page: a title, a line about it, and a scrollable column of content.
Flickable {
    id: scroll
    property string pageKey: ""
    property string title: ""
    property string description: ""
    readonly property bool isPage: true
    default property alias content: pageColumn.data

    visible: Ui.page === pageKey && Ui.query === ""
    anchors.fill: parent
    anchors.margins: 28
    anchors.rightMargin: 20
    contentWidth: width
    contentHeight: header.height + pageColumn.implicitHeight + 48
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function scrollTo(item) {
        var y = item.mapToItem(scroll.contentItem, 0, 0).y
        contentY = Math.max(0, Math.min(y - 24, contentHeight - height))
    }
    onVisibleChanged: if (visible) contentY = 0

    Column {
        id: header
        width: scroll.width - 8
        spacing: 4
        bottomPadding: 8
        Text { text: scroll.title; color: backend.palette.text; font.pixelSize: 26 }
        Text {
            width: parent.width
            visible: scroll.description !== ""
            text: scroll.description
            wrapMode: Text.WordWrap
            color: backend.palette.subtext
            font.pixelSize: 13
        }
    }
    Column {
        id: pageColumn
        y: header.height + 6
        width: scroll.width - 8
        spacing: 10
    }

    // Scroll position, so long pages show there is more below
    Rectangle {
        parent: scroll
        visible: scroll.visibleArea.heightRatio < 1
        x: scroll.width - 4
        y: scroll.visibleArea.yPosition * scroll.height
        width: 4; radius: 2
        height: scroll.visibleArea.heightRatio * scroll.height
        color: backend.palette.surface3
        opacity: scroll.moving ? 0.9 : 0.5
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
}
