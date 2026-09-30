import QtQuick
import qs.Ui
import "."
import qs.Commons

// One station row shared by Home / Stations / Search tabs. Plain Button with
// a cursor arrow and a star on the right; text stays inside the Button's own
// label so theming and presses come for free.
Button {
  id: row

  required property var panel
  property string title: ""
  property string detail: ""
  property bool hasCursor: false
  property color accent: Color.accent
  property color fg: Color.foreground
  property color muted: Color.muted
  property string fontFamily: Style.font.family

  signal favClicked()

  leftAlign: true
  text: (hasCursor ? "›  " : "   ") + title + (detail ? ("   " + detail) : "")
  fontSize: Style.font.body
  foreground: hasCursor ? row.accent : row.fg
  horizontalPadding: Style.space(8)
  verticalPadding: Style.space(5)

  // Star toggle on the right, hit area outside the Button's own mouseArea —
  // it sits above and swallows its own clicks.
  Item {
    anchors.right: row.right
    anchors.verticalCenter: row.verticalCenter
    width: Style.space(22)
    height: row.height

    Text {
      anchors.centerIn: parent
      text: "☆"
      color: area.containsMouse ? row.accent : Qt.alpha(row.muted, 0.55)
      font.family: row.fontFamily
      font.pixelSize: Style.font.caption
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.favClicked()
    }
  }
}
