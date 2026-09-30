import QtQuick
import qs.Ui
import "."
import qs.Commons

// SureTune Home: a quick player. One tap on a genre chip tunes a popular
// station from cliamp's radio provider, so "music now" needs no browsing.
Item {
  id: root

  required property var panel

  readonly property color fg: panel.fg
  readonly property color accent: panel.accent
  readonly property color muted: panel.muted
  readonly property string fontFamily: panel.fontFamily

  property var chips: ["Lofi", "Jazz", "Electronic", "Rock", "Classical", "News"]
  property var homeItems: []
  property int chip: -1
  property int cursor: -1          // into favorites then homeItems

  implicitHeight: content.implicitHeight

  function handleMessage(msg) {
    if (msg.type === "home") {
      homeItems = msg.items || []
      cursor = homeItems.length ? 0 : -1
      return true
    }
    if (msg.type === "favorites") return true   // panel keeps the list
    return false
  }

  function activated() { panel.send("status") }

  function moveCursor(dy) {
    var n = favoritesCount() + homeItems.length
    if (!n) return
    cursor = Math.max(0, Math.min(n - 1, cursor < 0 ? (dy > 0 ? 0 : n - 1) : cursor + dy))
  }

  function favoritesCount() { return panel.favorites.length }

  function activateCursor() {
    if (cursor < 0) { panel.playPause(); return }
    var favN = favoritesCount()
    if (cursor < favN) panel.play(panel.favorites[cursor])
    else {
      var i = cursor - favN
      if (i < homeItems.length) panel.play(homeItems[i])
    }
  }

  function textKey(t) {
    var c = chips[parseInt(t, 10) - 1] || null
    if (c) tuneChip(c)
  }

  function tuneChip(genre) {
    chip = chips.indexOf(genre)
    cursor = -1
    panel.sendJson("home", { genre: genre })
  }

  Column {
    id: content
    width: parent.width
    spacing: Style.space(10)

    // Big "press play" hero: honors the onStart preference in one click.
    Button {
      width: parent.width
      leftAlign: true
      text: {
        var lastTitle = panel.last && panel.last.title ? panel.last.title : ""
        if (panel.playing || panel.paused) return "Resume " + (lastTitle || "listening")
        if (panel.settings.onStart === "resume" && lastTitle) return "Play where you left off · " + lastTitle
        return "Play lofi to start"
      }
      fontFamily: root.fontFamily
      fontSize: Style.font.body
      foreground: root.accent
      onClicked: panel.playPause()
    }

    Flow {
      width: parent.width
      spacing: Style.space(6)

      Repeater {
        model: root.chips

        Button {
          required property string modelData
          required property int index
          text: modelData
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          selected: root.chip === index
          focusable: false
          horizontalPadding: Style.space(9)
          verticalPadding: Style.space(4)
          foreground: root.chip === index ? root.accent : root.fg
          onClicked: root.tuneChip(modelData)
        }
      }
    }

    Text {
      visible: root.favoritesCount() > 0
      text: "Favorites"
      textFormat: Text.PlainText
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }

    Repeater {
      model: root.panel.favorites

      ComponentBarRow {
        required property var modelData
        required property int index
        panel: root.panel
        title: modelData.title
        detail: modelData.codec || "favorite"
        hasCursor: root.cursor === index
        accent: root.accent
        fg: root.fg
        muted: root.muted
        fontFamily: root.fontFamily
        onClicked: root.panel.play(root.panel.favorites[index])
        onFavClicked: root.panel.toggleFavorite(root.panel.favorites[index])
      }
    }

    Text {
      visible: root.homeItems.length > 0
      text: (root.chip >= 0 ? root.chips[root.chip] : "Popular") + " · tap to tune"
      textFormat: Text.PlainText
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }

    Repeater {
      model: root.homeItems

      ComponentBarRow {
        required property var modelData
        required property int index
        panel: root.panel
        title: modelData.title
        detail: modelData.codec || "live"
        hasCursor: root.cursor === root.favoritesCount() + index
        accent: root.accent
        fg: root.fg
        muted: root.muted
        fontFamily: root.fontFamily
        onClicked: root.panel.play(root.homeItems[index])
        onFavClicked: root.panel.toggleFavorite(root.homeItems[index])
      }
    }

    Text {
      visible: root.homeItems.length === 0 && root.favoritesCount() === 0
      width: parent.width
      wrapMode: Text.WordWrap
      textFormat: Text.PlainText
      text: "Tap a genre to tune in, or press 2 for the station browser."
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
