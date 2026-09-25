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
const HALF_SECOND = 500;
const TEN = 10;

function loadModel() {
  const source = readFileSync(MODEL_PATH, "utf8").replace(/^\.pragma library\s*$/m, "");
  const context = { console: { warn: () => {} } };
  vm.createContext(context);
  vm.runInContext(source, context);
  return context;
}

const Model = loadModel();

test("defaults: F15 tapped every 30 s, stopped", () => {
  // ASSERT
  assert.deepEqual({ ...Model.DEFAULTS }, { enabled: false, action: "F15", interval: THIRTY, unit: "s", hold: 0, delay: 0 });
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
    const state = { enabled: true, action: "mouse", interval: 250, unit: "ms", hold: HALF_SECOND, delay: TEN };

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
    ["a negative hold", { hold: -1 }],
    ["a hold over the maximum", { hold: Model.MAXIMUM_HOLD_MILLISECONDS + 1 }],
    ["a non-numeric hold", { hold: "long" }],
    ["a negative delay", { delay: -1 }],
    ["a delay over the maximum", { delay: Model.MAXIMUM_DELAY_SECONDS + 1 }],
    ["a non-numeric delay", { delay: "later" }],
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

test.describe("scrolled", () => {
  const BOUNDS = { minimum: 0, maximum: 100, step: 1 };

  for (const [label, scroll, expected] of [
    ["one notch up adds a step", { notches: 1, isFast: false }, 51],
    ["one notch down takes a step", { notches: -1, isFast: false }, 49],
    ["Shift adds ten steps", { notches: 1, isFast: true }, 60],
    ["Shift takes ten steps", { notches: -1, isFast: true }, 40],
    ["several notches add up", { notches: 3, isFast: false }, 53],
    ["never goes over the maximum", { notches: 6, isFast: true }, 100],
    ["never goes under the minimum", { notches: -6, isFast: true }, 0],
  ]) {
    test(label, () => {
      // ACT
      const result = Model.scrolled(50, { ...BOUNDS, ...scroll });

      // ASSERT
      assert.equal(result, expected);
    });
  }

  test("scales with the field step", () => {
    // ACT
    const result = Model.scrolled(HALF_SECOND, { minimum: 0, maximum: Model.MAXIMUM_HOLD_MILLISECONDS, step: 100, notches: 1, isFast: true });

    // ASSERT
    assert.equal(result, HALF_SECOND + ONE_SECOND);
  });
});

test.describe("delayMilliseconds", () => {
  test("converts the delay from seconds", () => {
    // ASSERT
    assert.equal(Model.delayMilliseconds({ delay: TEN }), TEN * ONE_SECOND);
  });

  test("keeps no delay at zero", () => {
    // ASSERT
    assert.equal(Model.delayMilliseconds({ delay: 0 }), 0);
  });
});

test.describe("holdMilliseconds", () => {
  test("keeps a hold shorter than the interval", () => {
    // ASSERT
    assert.equal(Model.holdMilliseconds({ interval: THIRTY, unit: "s", hold: HALF_SECOND }), HALF_SECOND);
  });

  test("never outlasts the interval", () => {
    // ASSERT
    assert.equal(Model.holdMilliseconds({ interval: 200, unit: "ms", hold: HALF_SECOND }), 200);
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

  test("mentions the hold of a key", () => {
    // ASSERT
    assert.equal(Model.describe({ action: "F15", interval: 5, unit: "s", hold: HALF_SECOND }), "F15 held 500 ms every 5 s");
  });

  test("ignores the hold for the mouse", () => {
    // ASSERT
    assert.equal(Model.describe({ action: "mouse", interval: 5, unit: "s", hold: HALF_SECOND }), "Mouse 1 px every 5 s");
  });

  test("falls back to the keysym for a free key", () => {
    // ASSERT
    assert.equal(Model.actionLabel("Scroll_Lock"), "Scroll_Lock");
  });
});

test.describe("command", () => {
  test("nudges the mouse", () => {
    // ASSERT
    assert.deepEqual([...Model.command(SCRIPT_PATH, { action: "mouse", hold: HALF_SECOND })], [SCRIPT_PATH, "mouse"]);
  });

  test("taps a key", () => {
    // ARRANGE
    const state = { action: "F15", interval: THIRTY, unit: "s", hold: 0 };

    // ASSERT
    assert.deepEqual([...Model.command(SCRIPT_PATH, state)], [SCRIPT_PATH, "key", "F15", "0"]);
  });

  test("holds a key", () => {
    // ARRANGE
    const state = { action: "Shift_L", interval: THIRTY, unit: "s", hold: HALF_SECOND };

    // ASSERT
    assert.deepEqual([...Model.command(SCRIPT_PATH, state)], [SCRIPT_PATH, "key", "Shift_L", "500"]);
  });
});
