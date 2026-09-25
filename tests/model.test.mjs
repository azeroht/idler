// Unit tests for Model.js, the pure logic behind the bar widget.
// Model.js is a QML JavaScript library: its ".pragma library" header is
// dropped and the file runs in a sandbox that exposes its top-level names.
import { readFileSync } from "node:fs";
import { test } from "node:test";
import assert from "node:assert/strict";
import vm from "node:vm";

const MODEL_PATH = new URL("../Model.js", import.meta.url);
const SCRIPT_PATH = "/plugins/azeroht.idler/idler.sh";
const ONE_SECOND = 1000;
const THIRTY = 30;
const OVER_MAXIMUM_LENGTH = 33;

function loadModel() {
  const source = readFileSync(MODEL_PATH, "utf8").replace(/^\.pragma library\s*$/m, "");
  const context = { console: { warn: () => {} } };
  vm.createContext(context);
  vm.runInContext(source, context);
  return context;
}

const Model = loadModel();

test("defaults: F15 every 30 s, stopped", () => {
  // ASSERT
  assert.deepEqual({ ...Model.DEFAULTS }, { enabled: false, action: "F15", interval: THIRTY, unit: "s" });
});

test.describe("isKeysym", () => {
  for (const keysym of ["F15", "Shift_L", "space", "Scroll_Lock", "a"]) {
    test(`accepts ${keysym}`, () => {
      // ASSERT
      assert.equal(Model.isKeysym(keysym), true);
    });
  }

  for (const [label, value] of [
    ["an empty string", ""],
    ["undefined", undefined],
    ["a shell injection", "F15;rm"],
    ["an option", "-k"],
    ["a space", "F 15"],
    ["an accented letter", "é"],
    ["a keysym over 32 characters", "a".repeat(OVER_MAXIMUM_LENGTH)],
  ]) {
    test(`rejects ${label}`, () => {
      // ASSERT
      assert.equal(Model.isKeysym(value), false);
    });
  }
});

test.describe("normalize", () => {
  test("keeps a valid state", () => {
    // ARRANGE
    const state = { enabled: true, action: "mouse", interval: 250, unit: "ms" };

    // ACT
    const result = Model.normalize(state);

    // ASSERT
    assert.deepEqual({ ...result }, state);
  });

  for (const [label, raw] of [
    ["null", null],
    ["an empty object", {}],
    ["a truthy non-boolean enabled", { enabled: "yes" }],
    ["an unsafe action", { action: "F15;rm" }],
    ["a zero interval", { interval: 0 }],
    ["a negative interval", { interval: -5 }],
    ["an interval over a day", { interval: 86401 }],
    ["a non-numeric interval", { interval: "soon" }],
    ["an unknown unit", { unit: "min" }],
  ]) {
    test(`falls back to defaults for ${label}`, () => {
      // ACT
      const result = Model.normalize(raw);

      // ASSERT
      assert.deepEqual({ ...result }, { ...Model.DEFAULTS });
    });
  }

  test("rounds a fractional interval", () => {
    // ACT
    const result = Model.normalize({ interval: 2.6 });

    // ASSERT
    assert.equal(result.interval, 3);
  });
});

test.describe("parse", () => {
  test("reads a JSON state", () => {
    // ASSERT
    assert.deepEqual({ ...Model.parse('{"enabled":true}') }, { enabled: true });
  });

  test("returns an empty object for unreadable text", () => {
    // ASSERT
    assert.deepEqual({ ...Model.parse("{not json") }, {});
  });

  test("returns an empty object for an empty file", () => {
    // ASSERT
    assert.deepEqual({ ...Model.parse("null") }, {});
  });
});

test.describe("intervalMilliseconds", () => {
  test("converts seconds", () => {
    // ASSERT
    assert.equal(Model.intervalMilliseconds({ interval: THIRTY, unit: "s" }), THIRTY * ONE_SECOND);
  });

  test("keeps milliseconds", () => {
    // ASSERT
    assert.equal(Model.intervalMilliseconds({ interval: 250, unit: "ms" }), 250);
  });

  test("never goes under the 100 ms floor", () => {
    // ASSERT
    assert.equal(Model.intervalMilliseconds({ interval: 1, unit: "ms" }), Model.MINIMUM_MILLISECONDS);
  });
});

test.describe("isPreset", () => {
  for (const action of ["F15", "F13", "Shift_L", "mouse"]) {
    test(`recognizes the preset ${action}`, () => {
      // ASSERT
      assert.equal(Model.isPreset(action), true);
    });
  }

  test("treats any other keysym as a free key", () => {
    // ASSERT
    assert.equal(Model.isPreset("Scroll_Lock"), false);
  });
});

test.describe("describe and actionLabel", () => {
  test("uses the preset label", () => {
    // ASSERT
    assert.equal(Model.describe({ action: "mouse", interval: 5, unit: "s" }), "Mouse 1 px every 5 s");
  });

  test("falls back to the keysym for a free key", () => {
    // ASSERT
    assert.equal(Model.actionLabel("Scroll_Lock"), "Scroll_Lock");
  });
});

test.describe("themeGreen", () => {
  const GRUVBOX = 'accent = "#d79921"\ngreen = "#98971a"\nbright_green = "#b8bb26"\n';

  test("prefers the bright green", () => {
    // ASSERT
    assert.equal(Model.themeGreen(GRUVBOX), "#b8bb26");
  });

  test("falls back to the green", () => {
    // ASSERT
    assert.equal(Model.themeGreen('green = "#98971a"'), "#98971a");
  });

  test("is empty when the theme has no green", () => {
    // ASSERT
    assert.equal(Model.themeGreen('accent = "#d79921"'), "");
  });

  test("is empty for an unreadable theme", () => {
    // ASSERT
    assert.equal(Model.themeGreen(undefined), "");
  });

  test("ignores a key that only starts like green", () => {
    // ASSERT
    assert.equal(Model.themeGreen('green_dim = "#000000"'), "");
  });
});

test.describe("command", () => {
  test("nudges the mouse", () => {
    // ASSERT
    assert.deepEqual([...Model.command(SCRIPT_PATH, "mouse")], [SCRIPT_PATH, "mouse"]);
  });

  test("presses a key", () => {
    // ASSERT
    assert.deepEqual([...Model.command(SCRIPT_PATH, "F15")], [SCRIPT_PATH, "key", "F15"]);
  });
});
