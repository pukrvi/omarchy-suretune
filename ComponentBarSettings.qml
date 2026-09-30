import QtQuick
import qs.Ui
import "."
import qs.Commons

// SureTune Settings: defaults the user can change. onStart decides what the
// big play button does (lofi / resume / nothing); the default station name
// below shows exactly which stream "lofi" means.
Item {
  id: root

  required property var panel

  readonly property color fg: panel.fg
  readonly property color accent: panel.accent
  readonly property color muted: panel.muted
  readonly property string fontFamily: panel.fontFamily

  property var onStartOptions: [
    { key: "lofi", label: "Play lofi" },
    { key: "resume", label: "Resume where I left off" },
    { key: "none", label: "Do nothing" }
  ]

  implicitHeight: content.implicitHeight

  function handleMessage(msg) {
    if (msg.type === "settings") return true      // panel keeps the state
    return false
  }

  function activated() { panel.sendJson("settings", {}) }

  function setOnStart(value) {
    panel.sendJson("set", { key: "onStart", value: value })
  }

  Column {
    id: content
    width: parent.width
    spacing: Style.space(10)

    Text {
      text: "When I press play"
      textFormat: Text.PlainText
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }

    Repeater {
      model: root.onStartOptions

      Button {
        required property var modelData
        required property int index
        width: parent.width
        leftAlign: true
        text: (root.panel.settings.onStart === modelData.key ? "●  " : "○  ") + modelData.label
        fontFamily: root.fontFamily
        fontSize: Style.font.body
        foreground: root.panel.settings.onStart === modelData.key ? root.accent : root.fg
        focusable: false
        onClicked: root.setOnStart(modelData.key)
      }
    }

    Item { width: 1; height: Style.space(2) }
    Rectangle { width: parent.width; height: 1; color: Qt.alpha(root.fg, 0.08) }
    Item { width: 1; height: Style.space(2) }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      textFormat: Text.PlainText
      text: "\"Play lofi\" tunes Lilo-Fi Radio — a 24/7, ad-free stream."
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      textFormat: Text.PlainText
      text: "Favorites live on the Home tab — tap the ☆ beside any station. YT Music and Spotify sign in once through Search (cliamp providers)."
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      textFormat: Text.PlainText
      text: "Keys: 1-4 tabs · j/k rows · Enter play · Space pause · s stop · n/p next/prev · +/- volume · q close"
      color: Qt.alpha(root.muted, 0.8)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
