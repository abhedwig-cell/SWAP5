# PUB-GC macro-window high-count envelope qualification

Status: **frozen before execution**

Qualification ID: `PUB-GC-MACRO-WINDOW-QUAL-0003`

Publication owner: `PUB-GC`

Trigger decision:
`docs/publications/decisions/PUB-GC_NATIVE_TIME_REFINEMENT_AFTER_0002.md`

Baseline qualified macro authority:
`research/pub-gc-macro-time-coordinate@2fad7bb01f7d7d9b55dfca752efd02c502548389`

Qualified macro module blob:
`0a9461368f536381ca23390b255f8c369cb1e474`

Frozen production source tree:
`d7ef6c045263de821db7800459289efcd8a6420b`

## Purpose

Extend the qualification envelope of the unchanged research-only macro response from 32 to 128 native contributions before NATIVE-TIME-0003.

No production or macro-module code change is permitted.

## Qualification

Re-run all existing Q0-Q8 checks unchanged and add:

### Q9A
- macro origin 4200.125 d;
- duration 0.04 d;
- 64 x 0.000625 d;
- constant qualification forcing;
- prescribed bottom head -80 cm.

### Q9B
- same origin/duration;
- 128 x 0.0003125 d.

### Q9C
- macro origin 14200.125 d;
- duration 0.04 d;
- 128 x 0.0003125 d.

For each Q9 fixture require:
- response completed;
- exact expected contribution count;
- every represented native interval finite and positive;
- final disposable time bitwise equal to supplied macro_t1;
- authoritative origin unchanged;
- represented-duration telemetry available and finite.

Q9 numerical hydrologic values are qualification-only and prohibited from NATIVE-TIME case selection or H2/H3 inference.

O0/O2 exact scientific-output identity is mandatory.

## Allowed research mutations

Create `research/pub-gc-macro-high-count` from the baseline qualified macro head.

Allowed:
- macro qualification test/runner additions under `tests/publication/pub_gc/macro_window_response/**`;
- `.github/workflows/pub-gc-macro-high-count-qualification.yml`.

Forbidden:
- changes to the qualified macro module itself;
- `src/**`;
- all other qualified publication components.

## Pass meaning

PASS admits the unchanged research macro response for qualification use with up to 128 contributions under the stated temporal envelope. It does not establish H2, H3, production admission or a native timestep policy.
