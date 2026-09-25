import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Idler settings, styled like the native panels: on / off, the repeated
// action (preset keys, a free key or the mouse) with how long a key is held,
// and the interval with its unit. Every choice goes up through changed() and
// applies at once.
Column {
  id: panel
  property var state: Model.DEFAULTS
  signal changed(var changes)
  readonly property int panelWidth: Style.space(320)
  readonly property color foreground: Color.popups.text
  readonly property bool isCustomKey: !Model.isPreset(state.action)

  spacing: Style.spacing.panelGap

  component Choice: Button {
    fontSize: Style.font.bodySmall
    foreground: panel.foreground
    bordered: true
  }

  PanelHero {
    title: "Idler"
    meta: panel.state.enabled ? Model.describe(panel.state) : "Off"
    foreground: panel.foreground
    iconComponent: Component {
      Text {
        // Nerd Font: mouse.
        text: "\u{f037d}"
        color: panel.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.display
      }
    }
    trailingControl: Component {
      ToggleSwitch {
        checked: panel.state.enabled
        foreground: panel.foreground
        onToggled: panel.changed({ enabled: !panel.state.enabled })
      }
    }
  }

  PanelSeparator { foreground: panel.foreground }

  PanelSectionHeader { text: "ACTION"; foreground: panel.foreground; fontSize: Style.font.bodySmall }

  Grid {
    id: actions
    width: parent.width
    columns: 2
    spacing: Style.space(6)

    Repeater {
      model: Model.ACTIONS

      Choice {
        required property var modelData
        width: (actions.width - actions.spacing) / 2
        text: modelData.label
        active: panel.state.action === modelData.id
        onClicked: panel.changed({ action: modelData.id })
      }
    }
  }

  // Free key: a keysym (Scroll_Lock, space, F20...), applied on Enter.
  TextField {
    width: parent.width
    placeholderText: "Other key (keysym), Enter to apply"
    text: panel.isCustomKey ? panel.state.action : ""
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    foreground: panel.foreground
    onAccepted: if (Model.isKeysym(text)) panel.changed({ action: text })
  }

  // Hold: how long the key stays down on each pulse, 0 for a plain tap.
  NumberField {
    visible: panel.state.action !== Model.MOUSE
    label: "Hold (ms), 0 for a tap"
    from: 0
    to: Model.MAXIMUM_HOLD_MILLISECONDS
    stepSize: 100
    value: panel.state.hold
    foreground: panel.foreground
    fontSize: Style.font.bodySmall
    onModified: function(value) { panel.changed({ hold: value }) }
  }

  PanelSeparator { foreground: panel.foreground }

  PanelSectionHeader { text: "INTERVAL"; foreground: panel.foreground; fontSize: Style.font.bodySmall }

  Row {
    id: interval
    width: parent.width
    spacing: Style.space(6)

    NumberField {
      id: amount
      anchors.verticalCenter: parent.verticalCenter
      from: 1
      to: Model.MAXIMUM_INTERVAL
      value: panel.state.interval
      foreground: panel.foreground
      fontSize: Style.font.bodySmall
      onModified: function(value) { panel.changed({ interval: value }) }
    }

    Repeater {
      model: Object.keys(Model.UNITS)

      Choice {
        required property string modelData
        anchors.verticalCenter: parent.verticalCenter
        width: (interval.width - amount.width - interval.spacing * 2) / 2
        text: modelData
        active: panel.state.unit === modelData
        onClicked: panel.changed({ unit: modelData })
      }
    }
  }

  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    text: "Minimum " + Model.MINIMUM_MILLISECONDS + " ms. Left click on the bar icon starts or stops."
    color: panel.foreground
    opacity: 0.6
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
}
