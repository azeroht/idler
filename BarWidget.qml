import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Idler: simulated activity (a key press or a one-pixel cursor nudge) at the
// chosen interval, to keep the session and chat statuses active.
// Left click: start / stop. Right click: settings.
// The state (running, action, interval) survives shell restarts in
// ~/.local/state/azeroht-idler.json. Every monitor has its own bar, hence its
// own instance of this widget: they all follow that file, and only the
// instance on the first screen sends the pulses, so there is never two.
BarWidget {
  id: root
  moduleName: "azeroht.idler"

  property var state: Model.DEFAULTS
  property bool popupOpen: false
  readonly property string scriptPath: String(Qt.resolvedUrl("idler.sh")).replace("file://", "")
  readonly property bool sendsPulses: {
    const window = root.QsWindow.window
    return !!window && Quickshell.screens.length > 0 && window.screen === Quickshell.screens[0]
  }

  // Contract the bar expects to open and close the popup.
  readonly property bool opened: popupOpen
  function open() { popupOpen = true }
  function close() { popupOpen = false }

  // An IPC target reaches a single instance: it relays open to every bar, and
  // only the one on the focused monitor opens its panel.
  function openIfFocused() {
    const window = root.QsWindow.window
    const focused = Hyprland.focusedMonitor
    if (window && window.screen && focused && window.screen.name === focused.name) open()
  }

  function update(changes) {
    state = Model.normalize(Object.assign({}, state, changes))
    stateFile.setText(JSON.stringify(state, null, 2) + "\n")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // omarchy-shell azeroht.idler toggle | start | stop | open | close | status
  IpcHandler {
    target: "azeroht.idler"
    function toggle(): void { root.update({ enabled: !root.state.enabled }) }
    function start(): void { root.update({ enabled: true }) }
    function stop(): void { root.update({ enabled: false }) }
    function open(): void { root.broadcast("openIfFocused") }
    function close(): void { root.broadcast("close") }
    function status(): string { return root.state.enabled ? Model.describe(root.state) : "off" }
  }

  FileView {
    id: stateFile
    path: Color.stateHome + "/azeroht-idler.json"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.state = Model.normalize(Model.parse(text()))
  }

  Timer {
    interval: Model.intervalMilliseconds(root.state)
    running: root.state.enabled && root.sendsPulses
    repeat: true
    onTriggered: Quickshell.execDetached(Model.command(root.scriptPath, root.state.action))
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Nerd Font: mouse.
    text: "\u{f037d}"
    active: root.state.enabled
    tooltipText: root.state.enabled ? "Idler: " + Model.describe(root.state) : "Idler: off"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.popupOpen = !root.popupOpen
      else root.update({ enabled: !root.state.enabled })
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(settings.panelWidth)
    contentHeight: popup.fittedContentHeight(settings.implicitHeight)

    SettingsPanel {
      id: settings
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      state: root.state
      onChanged: function(changes) { root.update(changes) }
    }
  }
}
