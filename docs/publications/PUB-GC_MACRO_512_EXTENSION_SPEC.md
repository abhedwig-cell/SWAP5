# PUB-GC macro-window 256/512 contribution envelope qualification

Status: **frozen before execution**

Qualification ID: `PUB-GC-MACRO-WINDOW-QUAL-0004`

Publication owner: `PUB-GC`

Trigger decision:
`docs/publications/decisions/PUB-GC_NATIVE_TIME_REFINEMENT_AFTER_0003.md`

Trigger decision commit:
`f581b112add1ae2c7bf6dcce37557eaa22cf21a7`

Baseline qualified macro authority:
`research/pub-gc-macro-high-count@2189109de15df92d6712b5a3f5b27c1a922edd42`

Qualified macro module blob:
`0a9461368f536381ca23390b255f8c369cb1e474`

Frozen production source tree:
`d7ef6c045263de821db7800459289efcd8a6420b`

## Purpose

Extend the qualification envelope of the unchanged research-only macro response from 128 to 512 native contributions before NATIVE-TIME-0004.

No production or macro-module code change is permitted.

## Qualification

Re-run all existing Q0-Q9 checks unchanged and add:

### Q10A
- macro origin 4200.125 d;
- duration 0.04 d;
- 256 x 0.00015625 d;
- constant qualification forcing;
- prescribed bottom head -80 cm.

### Q10B
- same origin/duration;
- 512 x 0.000078125 d.

### Q10C
- macro origin 14200.125 d;
- duration 0.04 d;
- 512 x 0.000078125 d.

For each Q10 fixture require:
- response completed;
- exact expected contribution count;
- every represented native interval finite and positive;
- final disposable time bitwise equal to supplied macro_t1;
- authoritative origin unchanged;
- represented-duration telemetry available and finite.

Q10 numerical hydrologic values are qualification-only and prohibited from NATIVE-TIME case selection or H2/H3 inference.

O0/O2 exact scientific-output identity is mandatory.

## Allowed research mutations

Create `research/pub-gc-macro-512-envelope` from the baseline high-count qualified head.

Allowed:
- qualification-test/runner additions or extensions under `tests/publication/pub_gc/macro_window_response/**`;
- `.github/workflows/pub-gc-macro-512-qualification.yml`.

Forbidden:
- changes to `mod_pub_gc_macro_window_response.f90`;
- `src/**`;
- all other previously qualified publication components.

## Pass meaning

PASS admits the unchanged research macro response for supporting qualification use with up to 512 contributions under the stated temporal envelope.

It does not establish H2, H3, production admission, or a native timestep policy.
