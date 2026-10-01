# PPA-WU05-A12 preregistration — active perched serialized FMR runtime

Date: 2026-10-01

Status: `PREREGISTERED / PRODUCTION-ADMISSION-CANDIDATE_PATH`

Baseline: `research/ppa-wu05-a11-perched-zone-carrier@f0291d8c5c153417465a5bd8f464bd4a2fd88c33`

Canonical reconciliation point: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

## Purpose

Qualify the A11 source-faithful perched-zone carrier in the real serialized
Reference-Richards FMR predictor/corrector runtime, without widening the macropore
physics envelope beyond the standard SWAP route already bounded by A8-A11.

## Fixed dependencies

Inherited authority:

- A8: production FMR macropore adapter/runtime;
- A9: source-faithful dynamic top input;
- A10: main-domain rapid drainage;
- A11: exact 4.3.1 perched carrier and source-map qualification.

No A12 change may alter:

- seven-field macropore continuation-state schema;
- accepted/candidate/restart ownership;
- existing A8/A9/A10 top-input or rapid-drain formulas;
- Full Richards reference ownership;
- mass tolerances merely to obtain a pass.

## Qualified target

One serialized FMR case must actively produce a source-derived perched matrix zone during
the runtime predictor/corrector path and demonstrate:

### G1 — active runtime

- perched detection is enabled;
- the real runtime obtains a non-empty perched hydraulic view;
- `QInIntSat` contributes nonzero matrix-to-macropore exchange;
- the interval completes under the existing outer corrector;
- whole-column and internal exchange mass gates pass.

### G2 — transaction rejection

A deliberately rejected attempt must leave committed matrix and all seven macropore
continuation fields unchanged.

A subsequent accepted retry from the same checkpoint must reproduce the uninterrupted
accepted result.

### G3 — restart

After serializing/restoring the accepted A12 state, the next perched-active interval must
reproduce:

- candidate matrix state;
- all seven macropore continuation fields;
- perched/internal exchange receipt;
- external top and rapid-drain receipts when active;
- mass result.

### G4 — preservation

The complete A11 focused source/carrier gate and A10 preservation gate must remain green.

### G5 — production-admission candidate

Only after G1-G4 pass on one persisted postimage may A12 be classified as
`QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE`.

Canonical admission is a subsequent explicit step.

## Non-scope

A12 does not admit:

- covering-layer macropore physics;
- arbitrary/interpolated rapid-drain levels beyond A10;
- multiple rapid-drain levels;
- fixed-weir/Ribasim ownership in the same interval;
- within-corrector dynamic crack displacement feedback;
- RossFast;
- parallel/concurrent MultiSWAP.

## Evidence discipline

Use local/source-level reasoning and small fixtures where possible.

Use GitHub Actions only for the persisted A12 qualification/postimage and any required
canonical preservation evidence.

Do not silently replace the exact A11 `CritUndSatVol` carrier by a pressure-head-sign
shortcut.
