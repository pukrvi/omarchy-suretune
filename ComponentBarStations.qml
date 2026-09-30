import QtQuick
import qs.Ui
import "."
import qs.Commons

// SureTune Stations: the full browser over the merged catalogue — Lofi Focus
// streams, Hertz Radio's Radio Browser cache, and cliamp's radio provider —
// with genre chips and a free-text filter. "All" shows everything; a genre
// chip matches text against the titles/details; "/" searches cliamp live.
Item {
  id: root

  required property var panel

  readonly property color fg: panel.fg
  readonly property color accent: panel.accent
  readonly property color muted: panel.muted
  readonly property string fontFamily: panel.fontFamily

  property var genres: ["All", "Lofi", "Jazz", "Blues", "Classical", "Electronic",
                        "Hip Hop", "Pop", "Rock", "Metal", "Chillout", "Folk",
                        "Country", "Reggae", "News"]
  property string genreFilter: "All"
  property string text: ""
  property var allStations: []
  property var stations: []
  property bool loading: false
  property string listError: ""
  property int cursor: -1
  property bool editorFocus: false
  property var counts: ({})

  implicitHeight: content.implicitHeight
  readonly property bool keyBlock: editorFocus

  function handleMessage(msg) {
    if (msg.type === "browse") {
      if (msg.genres && msg.genres.length) genres = msg.genres
      counts = msg.counts || {}
      listError = ""
      loading = false
      allStations = msg.items || []
      applyFilter()
      return true
    }
    if (msg.type === "stations") {
      // Live cliamp search result ("+" tag or "/" free text path).
      loading = false
      if (msg.error) { listError = msg.error; return true }
      listError = ""
      stations = msg.items || []
      cursor = stations.length ? 0 : -1
      return true
    }
    return false
  }

  function activated() {
    if (!allStations.length && !loading && stations.length === 0) browse()
  }

  function browse() {
    loading = true
    listError = ""
    panel.send("browse")
  }

  function applyFilter() {
    var needle = text.toLowerCase()
    var tag = genreFilter.toLowerCase()
    var rows = []
    for (var i = 0; i < allStations.length; i++) {
      var row = allStations[i]
      if (tag !== "all") {
        var hay = (row.title + " " + (row.detail || "")).toLowerCase()
        if (hay.indexOf(tag) === -1) continue
      }
      if (needle && (row.title + " " + (row.detail || "")).toLowerCase().indexOf(needle) === -1)
        continue
      rows.push(row)
    }
    stations = rows
    cursor = rows.length ? 0 : -1
  }

  function selectGenre(g) {
    if (genreFilter === g) return
    genreFilter = g
    cursor = -1
    applyFilter()
  }

  function moveCursor(dy) {
    var n = stations.length
    if (!n) return
    cursor = Math.max(0, Math.min(n - 1, cursor < 0 ? (dy > 0 ? 0 : n - 1) : cursor + dy))
  }

  function activateCursor() {
    if (cursor >= 0 && cursor < stations.length) panel.play(stations[cursor])
  }

  function textKey(t) {
    if (t === "/") searchField.forceActiveFocus()
  }

  function sourceLabel(source) {
    if (source === "lofi") return "lofi"
    if (source === "radio") return "cliamp"
    return "stations"
  }

  Column {
    id: content
    width: parent.width
    spacing: Style.space(10)

    // Source summary line
    Text {
      textFormat: Text.PlainText
      text: {
        var parts = []
        if (root.counts.lofi) parts.push(root.counts.lofi + " lofi")
        if (root.counts.stations) parts.push(root.counts.stations + " radio")
        if (root.counts.radio) parts.push(root.counts.radio + " cliamp")
        return parts.length ? parts.join("  ·  ") + "  —  filtered below" : "loading catalogue…"
      }
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    // Genre chips
    Flow {
      width: parent.width
      spacing: Style.space(6)

      Repeater {
        model: root.genres

        Button {
          required property string modelData
          required property int index
          text: modelData
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          selected: root.genreFilter === modelData
          focusable: false
          horizontalPadding: Style.space(8)
          verticalPadding: Style.space(3)
          foreground: root.genreFilter === modelData ? root.accent : root.fg
          onClicked: root.selectGenre(modelData)
        }
      }
    }

    TextField {
      id: searchField
      width: parent.width
      placeholderText: "/ filter by name…"
      font.family: root.fontFamily
      onTextChanged: {
        if (text === root.text) return
        filterDebounce.restart()
      }
    }

    Timer {
      id: filterDebounce
      interval: 220
      onTriggered: { root.text = searchField.text; root.applyFilter() }
    }

    Text {
      visible: root.listError !== ""
      width: parent.width
      wrapMode: Text.WrapAnywhere
      text: root.listError
      color: root.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      visible: root.loading
      text: "gathering stations…"
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Repeater {
      model: root.stations

      ComponentBarRow {
        required property var modelData
        required property int index
        panel: root.panel
        title: modelData.title
        detail: (modelData.source ? root.sourceLabel(modelData.source) : "") +
                (modelData.detail ? " · " + modelData.detail : "")
        hasCursor: root.cursor === index
        accent: root.accent
        fg: root.fg
        muted: root.muted
        fontFamily: root.fontFamily
        onClicked: root.panel.play(root.stations[index])
        onFavClicked: root.panel.toggleFavorite(root.stations[index])
      }
    }

    Button {
      visible: !root.loading && root.allStations.length === 0 && root.listError === ""
      text: "Load the catalogue"
      fontFamily: root.fontFamily
      fontSize: Style.font.caption
      foreground: root.accent
      onClicked: root.browse()
    }

    Text {
      visible: !root.loading && root.allStations.length > 0 && root.stations.length === 0
      text: "Nothing matches this filter."
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
