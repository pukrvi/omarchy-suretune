import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import "."
import qs.Commons

// SureTune: one bar icon for all of Omarchy's radio.
//
// The player controls live in a sticky header at the top of every tab. Tabs:
// Home (chips + favorites), Stations (merged catalogue from cliamp, Hertz and
// Lofi Focus), Search (YT Music / Spotify via cliamp), Settings. Playback is
// always cliamp's job: this panel renders JSON snapshots from ./suretune-ctl
// and sends one-line verbs back.
//
// Keyboard: 1-4 switch tabs, h/l or ←/→ tabs, j/k or ↑/↓ move the row cursor,
// Enter/Space activate (Space toggles playback when nothing is selected),
// s=stop, n/p=next/prev, +/- volume, q or Esc closes.
Panel {
  id: root
  moduleName: "vishnawat.suretune"
  ipcTarget: "suretune"

  // ---------------------------------------------------------------- state

  property bool connected: false
  property bool playing: false
  property bool paused: false
  property string nowTitle: ""
  property string stationName: ""
  property string playError: ""
  property int volume: 70
  property int tab: 0
  property var favorites: []
  property var last: null
  property string ytmLogin: ""   // "yes" (OAuth creds) | "cookie" | "no" | ""
  property string ytmDetail: ""
  property var settings: ({ onStart: "lofi", volume: 70 })

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color surfaceColor: {
    var c = Color.popups.background
    return Qt.rgba(c.r, c.g, c.b, 1)
  }
  readonly property color muted: Color.muted

  readonly property var tabs: ["Home", "Stations", "Search", "Settings"]
  readonly property bool live: playing && !paused && playError === ""
  readonly property var current: stack.item

  // ---------------------------------------------------------------- backend

  readonly property string ctlPath: decodeURIComponent(String(Qt.resolvedUrl("suretune-ctl")).replace(/^file:\/\//, ""))

  function send(line) {
    if (backend.running) backend.write(line + "\n")
  }

  function sendJson(verb, obj) { send(verb + " " + JSON.stringify(obj)) }

  function handle(line) {
    var msg
    try { msg = JSON.parse(line) } catch (e) { return }
    if (msg.type === "status" || msg.type === "error") {
      if (msg.type === "status") {
        playing = !!msg.playing
        paused = !!msg.paused
        nowTitle = msg.title || ""
        stationName = msg.station || ""
        if (msg.ok === false) playError = msg.error || "cliamp unreachable"
        else if (playing || paused) playError = ""
        if (typeof msg.volume === "number") volume = msg.volume
        if (msg.ytmusic) {
          ytmLogin = msg.ytmusic.login || ""
          ytmDetail = msg.ytmusic.detail || ""
          if (ytmLogin !== "" && loginPoll.running) {   // login landed (or gone)
            loginPoll.stop()
            stack.item && stack.item.handleMessage && stack.item.handleMessage({ type: "login" })
          }
        }
        if (msg.favorites) favorites = msg.favorites
        if (msg.last) last = msg.last
        if (msg.settings) settings = msg.settings
      } else {
        playError = msg.message || ""
      }
      return
    }
    if (msg.type === "favorites") favorites = msg.items || favorites
    else if (msg.type === "settings" && msg.items) settings = msg.items
    // Tab-owned payloads go to the mounted tab; tabs filter by their own keys.
    if (stack.item && stack.item.handleMessage && stack.item.handleMessage(msg)) return
  }

  function play(track) { if (track && track.path) sendJson("play", track) }
  function playPause() { send("toggle") }        // backend decides play-first vs toggle
  function stop() { send("stop") }
  function next() { send("next") }
  function prev() { send("prev") }
  function setVolume(v) { sendJson("volume", { value: Math.max(0, Math.min(100, Math.round(v))) }) }
  function toggleFavorite(track) { sendJson("fav", track) }

  function switchTab(i) {
    tab = Math.max(0, Math.min(tabs.length - 1, i))
    Qt.callLater(function() { if (current && current.activated) current.activated() })
  }

  Process {
    id: backend
    command: ["python3", root.ctlPath, "daemon"]
    running: true
    stdinEnabled: true
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) { root.handle(data) }
    }
    stderr: SplitParser {
      onRead: function(data) { console.warn("suretune-ctl:", data) }
    }
    onRunningChanged: root.connected = running
    onExited: function(code) {
      root.connected = false
      restartTimer.start()
    }
  }

  Timer {
    id: restartTimer
    interval: 3000
    onTriggered: backend.running = true
  }

  onOpenedChanged: {
    if (opened) Qt.callLater(function() { send("status") })
  }

  // After a setup/login run completes, re-probe so the UI flips without a bar
  // reload: Nudge wakes a freshly-started login terminal, then a status pull.
  Timer {
    id: loginPoll
    interval: 15000
    repeat: true
    running: false
    onTriggered: { if (root.opened) root.send("status") }
  }

  // ---------------------------------------------------------------- bar icon

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: {
      if (!root.playing && !root.paused) return "SureTune"
      var name = root.stationName || root.nowTitle || "Radio"
      if (root.playError) return name + " · " + root.playError
      if (root.paused) return name + " · paused"
      return root.nowTitle ? name + " · " + root.nowTitle : name
    }
    text: root.live ? "󰎈" : (root.paused ? "󰏤" : "󰐋")
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.playPause()
      else if (b === Qt.RightButton) root.stop()
      else root.toggle()
    }
    onWheelMoved: function(delta) { root.setVolume(root.volume + (delta > 0 ? 5 : -5)) }
  }

  // ---------------------------------------------------------------- panel

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(Math.min(contentColumn.implicitHeight, Style.space(620)))

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      blocked: root.current && root.current.keyBlock ? root.current.keyBlock : false

      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dy !== 0 && root.current && root.current.moveCursor) root.current.moveCursor(dy)
        else if (dx !== 0) root.switchTab(root.tab + dx)
      }
      onTextKey: function(t) {
        var i = parseInt(t, 10)
        if (i >= 1 && i <= root.tabs.length) { root.switchTab(i - 1); return }
        if (t === "s" || t === "S") { root.stop(); return }
        if (t === "n" || t === "N") { root.next(); return }
        if (t === "p" || t === "P") { root.prev(); return }
        if (t === "+" || t === "=") { root.setVolume(root.volume + 5); return }
        if (t === "-" || t === "_") { root.setVolume(root.volume - 5); return }
        if (root.current && root.current.textKey) root.current.textKey(t)
      }
      onReturnRequested: { }
      onActivateRequested: {
        if (root.current && root.current.activateCursor) root.current.activateCursor()
        else root.playPause()
      }

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(12)

        // ================= STICKY PLAYER HEADER (shared by all tabs) =========

        Column {
          width: parent.width
          spacing: Style.space(8)

          // Now-playing strip
          Column {
            width: parent.width
            spacing: Style.space(2)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: "SureTune"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              elide: Text.ElideRight
              text: {
                if (!root.connected) return "waking cliamp…"
                if (root.playError) return root.playError
                if (!root.stationName && !root.nowTitle) return "Press play to tune in."
                return root.paused ? root.nowTitle + "  ·  paused" : root.nowTitle
              }
              color: root.playError ? root.accent : (root.muted)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // Transport bar
          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              id: playButton
              iconText: root.live ? "󰏤" : "󰐋"
              tooltipText: root.live ? "Pause" : "Play"
              foreground: root.fg
              focusable: true
              selected: false
              onClicked: root.playPause()
            }
            Button {
              iconText: "󰝛"
              tooltipText: "Stop (s)"
              foreground: root.fg
              focusable: true
              onClicked: root.stop()
            }
            Button {
              iconText: "󰒮"
              tooltipText: "Previous"
              foreground: root.fg
              focusable: true
              onClicked: root.prev()
            }
            Button {
              iconText: "󰒭"
              tooltipText: "Next"
              foreground: root.fg
              focusable: true
              onClicked: root.next()
            }

            Item { width: Style.space(6); height: 1 }

            // Volume inline in the header
            Row {
              spacing: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter

              Button {
                iconText: root.volume === 0 ? "󰝟" : (root.volume < 50 ? "󰕿" : "󰕾")
                tooltipText: "Volume (+ / -)"
                foreground: root.fg
                focusable: true
                onClicked: root.setVolume(root.volume > 0 ? 0 : 70)
              }

              Item {
                width: Style.space(74)
                height: Style.space(20)

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  width: parent.width
                  height: 3
                  radius: 1
                  color: Qt.alpha(root.fg, 0.16)
                }
                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  width: Math.max(3, parent.width * root.volume / 100)
                  height: 3
                  radius: 1
                  color: root.accent
                  Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: function(mouse) { root.setVolume(mouse.x / width * 100) }
                  onPositionChanged: function(mouse) {
                    if (pressed) root.setVolume(mouse.x / width * 100)
                  }
                }
              }

              Text {
                text: root.volume + "%"
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }

        // Rectangle separating the sticky header from the tabs
        Item { width: parent.width; height: 1 }
        Rectangle {
          width: parent.width
          height: 1
          color: Qt.alpha(root.fg, 0.12)
        }

        // ================= TAB STRIP ====================

        Row {
          width: parent.width
          spacing: Style.space(4)

          Repeater {
            model: root.tabs

            Button {
              required property string modelData
              required property int index
              text: modelData
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              selected: root.tab === index
              focusable: false
              horizontalPadding: Style.space(8)
              verticalPadding: Style.space(3)
              foreground: root.tab === index ? root.accent : root.muted
              onClicked: root.switchTab(index)
            }
          }
        }

        // ================= TAB CONTENT ====================

        Loader {
          id: stack
          width: parent.width
          sourceComponent: [homeComp, stationsComp, searchComp, settingsComp][root.tab]
        }

        Component {
          id: homeComp
          ComponentBarHome { panel: root }
        }

        Component {
          id: stationsComp
          ComponentBarStations { panel: root }
        }

        Component {
          id: searchComp
          ComponentBarSearch { panel: root }
        }

        Component {
          id: settingsComp
          ComponentBarSettings { panel: root }
        }
      }
    }
  }
}
