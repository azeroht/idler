.pragma library

// Actions offered in the panel: a key (a keysym handed to wtype) or the
// cursor nudged one pixel right and back. F13 to F15 are bound to nothing.
var MOUSE = "mouse"
var ACTIONS = [
  { id: "F15", label: "F15" },
  { id: "F13", label: "F13" },
  { id: "Shift_L", label: "Shift" },
  { id: MOUSE, label: "Mouse 1 px" }
]

var UNITS = { ms: 1, s: 1000 }
// Floor against an event flood: at most ten pulses per second.
var MINIMUM_MILLISECONDS = 100
var MAXIMUM_INTERVAL = 86400
var KEYSYM_MAXIMUM_LENGTH = 32
var DEFAULTS = { enabled: false, action: "F15", interval: 30, unit: "s" }

var KEYSYM_CHARACTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"

// An X11 keysym (F15, Shift_L, space...): letters, digits and underscores
// only, so it can never pass for an option or a command.
function isKeysym(value) {
  var text = String(value || "")
  if (text.length === 0 || text.length > KEYSYM_MAXIMUM_LENGTH) return false
  for (var index = 0; index < text.length; index++) {
    if (KEYSYM_CHARACTERS.indexOf(text[index]) < 0) return false
  }
  return true
}

function isValidAction(action) {
  return action === MOUSE || isKeysym(action)
}

function parse(text) {
  try {
    return JSON.parse(text) || {}
  } catch (error) {
    console.warn("azeroht.idler: unreadable state, using defaults", error)
    return {}
  }
}

// A complete and safe state, whatever was read from disk.
function normalize(raw) {
  var source = raw || {}
  var interval = Math.round(Number(source.interval))
  return {
    enabled: source.enabled === true,
    action: isValidAction(source.action) ? source.action : DEFAULTS.action,
    interval: interval >= 1 && interval <= MAXIMUM_INTERVAL ? interval : DEFAULTS.interval,
    unit: UNITS[source.unit] !== undefined ? source.unit : DEFAULTS.unit
  }
}

function intervalMilliseconds(state) {
  return Math.max(MINIMUM_MILLISECONDS, state.interval * UNITS[state.unit])
}

// A preset action has its own button; any other keysym is a free key.
function isPreset(action) {
  for (var index = 0; index < ACTIONS.length; index++) {
    if (ACTIONS[index].id === action) return true
  }
  return false
}

function actionLabel(action) {
  for (var index = 0; index < ACTIONS.length; index++) {
    if (ACTIONS[index].id === action) return ACTIONS[index].label
  }
  return action
}

function describe(state) {
  return actionLabel(state.action) + " every " + state.interval + " " + state.unit
}

function command(scriptPath, action) {
  return action === MOUSE ? [scriptPath, MOUSE] : [scriptPath, "key", action]
}
