# PPA-WU05-A11 result — source-faithful FMR perched-zone carrier

Date: 2026-10-01

Status: `QUALIFIED_FMR_PERCHED_CARRIER_FOLLOWUP_RESULT`

Baseline: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

Qualified code/test postimage: `2ad9cbda64a53707730990dd436588a47b86b5b2`

Exact source-map postimage: `e11b7dc0593a1d49b7899b2c6349ab9ea019e456`

Qualification workflow: `.github/workflows/ppa-wu05a11-perched.yml`

Qualification run: `36834246991` — SUCCESS

## Exact-source authority

The user-provided `SWAP_4.3.1.zip` contains the exact A1-pinned nested source archive:

`SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP`

with:

- 411,215 bytes;
- SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

Relevant exact members include:

- `SWAP/macropore.f90`: SHA-256
  `1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0b`;
- `SWAP/macrorate.f90`: SHA-256
  `537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7`;
- `SWAP/calcgwl.f90`: SHA-256
  `d7649f02bf6cd629cc7eceb1c761a6c38d6f0adf0d0c072c7aaab3af4562f5eb`.

The full carrier source map is persisted in
`docs/audits/PPA_WU05A11_SOURCE_MAP.md`.

## Qualified capability

A11 adds an explicit, opt-in FMR carrier for the standard SWAP perched/top saturated
matrix-zone macropore path.

Qualified:

- source-faithful perched-zone detection from current matrix state;
- cumulative under-saturated-volume criterion using `CritUndSatVol`;
- source-faithful zero-head interpolation for perched top and bottom levels;
- derived top and bottom perched-zone compartment indices;
- explicit distinction between a partially saturated top compartment and a fully
  saturated top compartment;
- reuse of the existing A6 perched exclusion in unsaturated absorption;
- reuse of the existing A6 SATFLOW evaluator for `QInIntSatDmCp`;
- internal matrix/macropore mass ownership unchanged;
- no new continuation state;
- no restart-schema expansion;
- no solver-policy change.

The carrier is recomputed for each matrix trial from dynamic matrix state plus immutable
configuration.

## Source-oracle evidence

The focused fixture contains a 0.01 cm under-saturated-volume gap.

With `CritUndSatVol=0.005 cm`:

- the gap is a real separator;
- perched zone = compartment 4 only;
- perched water level = `-25.32258064516129 cm`.

With `CritUndSatVol=0.02 cm`:

- the gap is bridged;
- perched zone = compartments 3 through 4;
- perched water level = `-12.142857142857142 cm`;
- perched bottom level = `-38.75 cm`.

These values follow the exact `calcgwl.f90` interpolation and water-table search.

## FMR/A6 composition evidence

The focused gate proves that the derived A11 view populates:

- `sorptivity.perched_active`;
- `perched_top_node`;
- `perched_bottom_node`;
- `interflow_sat.matrix_top_saturated_node`;
- `interflow_sat.matrix_bottom_saturated_node`;
- perched reference water level;
- partial-top semantics.

The resulting A6 bundle:

- suppresses unsaturated absorption inside the perched interval;
- produces positive perched matrix-to-macropore interflow;
- exposes that transfer with negative `QExc_to_matrix` sign, consistent with the
  source-bound internal-exchange convention.

## Qualification and preservation

Run `36834246991` completed successfully on exact postimage `2ad9cbda...`.

Its focused A11 step requires the markers:

- `PPA_WU05A11_PERCHED_SOURCE_ORACLE=PASS`;
- `PPA_WU05A11_PERCHED_FMR_CARRIER=PASS`;
- `PPA_WU05A11_PERCHED_GATE=PASS`.

The same job then executes the complete A10 preservation script. That step passed,
therefore preserving the previously admitted A7/A8/A9/A10 serialized
Reference-Richards macropore chain, including A9 top input and A10 rapid drainage.

O0/O2 output identity is part of both focused gate scripts.

## Preservation strategy

A11 perched detection is explicitly opt-in.

Existing A8/A9/A10 configurations remain neutral unless
`perched_enabled=.true.` is supplied. This avoids silently expanding the already admitted
canonical envelope.

The default saturated-exchange partial-top behavior is also preserved. A11 only exposes an
explicit boolean so the source case `ICpSatPeGwl=-1` can be represented.

## What this result does not admit

A11 is **not** yet a canonical production admission.

This result does not yet prove:

- full active perched-zone execution through a complete serialized FMR
  predictor/corrector trial;
- active perched reject/discard/replay;
- active perched persistence/restart continuation;
- canonical admission;
- arbitrary covering-layer physics;
- within-corrector dynamic crack displacement feedback;
- RossFast;
- parallel/concurrent MultiSWAP.

Those require a bounded follow-on runtime qualification rather than widening this source/carrier gate.

## Decision

`QUALIFIED_SOURCE_FAITHFUL_FMR_PERCHED_CARRIER_READY_FOR_RUNTIME_TRIAL_FOLLOWON`

Lifecycle reached in A11:

`implemented -> persisted -> tested -> qualified`

Canonical admission is not claimed.

The frozen Status-A denominator remains unchanged.
