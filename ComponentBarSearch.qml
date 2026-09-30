import QtQuick
import qs.Ui
import "."
import qs.Commons

// SureTune Search: YT Music and Spotify — played back via cliamp providers.
// First time either tab is used SureTune offers `cliamp setup <provider>` so
// the user logs in once in their browser; after that it just works.
Item {
  id: root

  required property var panel

  readonly property color fg: panel.fg
  readonly property color accent: panel.accent
  readonly property color muted: panel.muted
  readonly property string fontFamily: panel.fontFamily

  property var providers: ["ytmusic", "spotify"]
  property var labels: ["YT Music", "Spotify"]
  property int provider: 0
  property var results: []
  property string searchError: ""
  property bool setupNeeded: false
  property bool loading: false
  property string text: ""
  property int cursor: -1
  property bool editorFocus: false

  implicitHeight: content.implicitHeight
  readonly property bool keyBlock: editorFocus

  function handleMessage(msg) {
    if (msg.type === "search" && msg.provider === providers[provider]) {
      loading = false
      searchError = msg.error || ""
      setupNeeded = !!msg.setup
      results = msg.items || []
      cursor = results.length ? 0 : -1
      return true
    }
    // A login run came back: drop the setup hint and try a real search to
    // prove it (the panel's login poll stops once the probe flips).
    if (msg.type === "login") {
      setupNeeded = panel.ytmLogin === "no"
      if (!setupNeeded && text !== "" && !loading) doSearch()
      return true
    }
    return false
  }

  function activated() {
    if (!results.length && !loading && text !== "") doSearch()
  }

  function doSearch() {
    if (!text.trim()) return
    loading = true
    searchError = ""
    panel.sendJson("search", { provider: providers[provider], query: text })
  }

  function moveCursor(dy) {
    var n = results.length
    if (!n) return
    cursor = Math.max(0, Math.min(n - 1, cursor < 0 ? (dy > 0 ? 0 : n - 1) : cursor + dy))
  }

  function activateCursor() {
    if (cursor >= 0 && cursor < results.length) panel.play(results[cursor])
  }

  function textKey(t) {
    if (t === "/") searchField.forceActiveFocus()
  }

  Column {
    id: content
    width: parent.width
    spacing: Style.space(10)

    Row {
      spacing: Style.space(6)

      Repeater {
        model: root.labels

        Button {
          required property string modelData
          required property int index
          text: modelData
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          selected: root.provider === index
          focusable: false
          horizontalPadding: Style.space(8)
          verticalPadding: Style.space(3)
          foreground: root.provider === index ? root.accent : root.fg
          onClicked: {
            if (root.provider !== index) {
              root.provider = index
              root.results = []
              root.searchError = ""
              root.cursor = -1
            }
            root.searchField.forceActiveFocus()
          }
        }
      }
    }

    TextField {
      id: searchField
      width: parent.width
      placeholderText: "/ search " + root.labels[root.provider] + "…"
      font.family: root.fontFamily
      onTextChanged: { if (text === root.text) return; searchDebounce.restart() }
    }

    Timer {
      id: searchDebounce
      interval: 500
      onTriggered: { root.text = searchField.text; root.doSearch() }
    }

    // Setup hint: shown only when cliamp reports the provider is unknown.
    Column {
      visible: root.setupNeeded
      width: parent.width
      spacing: Style.space(6)

      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: {
          var p = root.providers[root.provider]
          if (p === "ytmusic" && root.panel.ytmDetail !== "")
            return root.labels[root.provider] + " uses " + root.panel.ytmDetail +
                   " browser cookies. Signed in? Then it already works — if a search still fails, sign in to youtube.com there or update yt-dlp."
          return root.labels[root.provider] + " isn't connected. Sign in once — cliamp opens your browser and stores the token locally."
        }
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Button {
        text: "Sign in with cliamp…"
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        foreground: root.accent
        onClicked: {
          panel.sendJson("setup", { provider: root.providers[root.provider] })
          panel.loginPoll.start()   // re-probe until login lands
        }
      }
    }

    Text {
      visible: root.searchError !== "" && !root.setupNeeded
      width: parent.width
      wrapMode: Text.WrapAnywhere
      text: root.searchError
      color: root.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      visible: root.loading
      text: "searching…"
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Repeater {
      model: root.results

      ComponentBarRow {
        required property var modelData
        required property int index
        panel: root.panel
        title: modelData.title
        detail: ""
        hasCursor: root.cursor === index
        accent: root.accent
        fg: root.fg
        muted: root.muted
        fontFamily: root.fontFamily
        onClicked: root.panel.play(root.results[index])
        onFavClicked: root.panel.toggleFavorite(root.results[index])
      }
    }

    Text {
      visible: root.results.length === 0 && !root.loading && root.searchError === "" && root.text !== ""
      text: "Nothing found."
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
