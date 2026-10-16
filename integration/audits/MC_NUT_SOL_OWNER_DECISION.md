# MC-NUT01 / MC-SOL01 state and owner decision

Status: original source component plus bounded explicit vegetative request
binding admitted via PR1253; not full historical crop-N runtime admission.
Baseline: `integration/f-ci-canonical@be8a49cd59815b537b46e0dac2b3d0161366c796`

PR #1098 completes only its separate pure B1.11 request/fixation component.
The original ownership and sequencing proposal below is historical navigation;
current admitted Soil-N, crop-N, matrix/age and surface routes are owned by their
later canonical status records, including `MC_NUT_SOL_TRAJECTORY3_STATUS.json`.
At the original component admission, it had no production caller or runtime N-input receipt.
The bounded request-binding successor is tracked in
`MC_NUT_SOL_STATUS.json#b111_request_binding_20261016` and
`docs/science/MC_NUT01_B111_REQUEST_BINDING_CONTRACT_20261016.md`.
It explicitly selects this request inside the existing joint N owner, with
fresh mass/restart qualification; it does not assert full B1.11 crop-N equivalence.
It does not replace or alter the admitted WOFOST81 request/apply semantics.

## Ownership decomposition

The existing admitted matrix-solute route remains the only mobile dissolved
solute owner. Its committed node salt mass remains authoritative and
concentration remains a derived view from the matching committed/trial water
state. Sorption and decay must extend that owner rather than create a second
independently committed solute state.

The remaining stores are distinct physical authorities:

| Store | Persistent authority | Transfers owned here |
| --- | --- | --- |
| matrix dissolved solute | existing FMR optional salt component | top/bottom, drainage, root uptake and inter-node transport |
| matrix sorbed solute | MC-SOL01 reactive-storage extension | equilibrium dissolved/sorbed repartition only |
| pond solute | MC-SOL01 pond component | rain/irrigation/runoff/infiltration exchange with one surface donor |
| aquifer solute | MC-SOL01 aquifer component | drainage/bottom exchange and breakthrough |
| age tracer | dedicated tracer amount, not salt concentration | advective/dispersive carriers plus age production |
| mineral soil N | MC-NUT01 Soil-N owner | NH4/NO3 transport, plant uptake, nitrification and denitrification |
| organic soil C/N | MC-NUT01 Soil-N owner | mineralisation/immobilisation, amendments and crop residues |
| crop N | crop owner | demand, uptake receipt, fixation input and crop internal redistribution |

All persistent stores must live in the same accepted physical transaction as
their coupled water/crop state or in an explicitly atomic composite owned by
that transaction. Rejected trials may return candidate diagnostics but may not
mutate any committed nutrient or solute store.

## Sequencing

MC-SOL01 proceeds from the already admitted conservative matrix transport:
reactive storage, then decay, then pond/aquifer stores, then age tracer.

MC-NUT01 first introduces one Soil-N inventory owner for mineral and organic
pools. Reactions and crop exchange operate on candidate inventory receipts.
Amendments and residues are management transfers into that same owner. No
reaction routine owns persistence independently.

## B1.11 fixation policy

`SW431-NUT-NFIX` is not implemented by changing WOFOST81. The admitted
WOFOST81 request semantics remain unchanged.

A separate B1.11 fixation policy owns only the old selectable demand rule:
vegetative N deficits, strict `DVS < DVSNLT`, strict `RELTR > 0.01`, and
partition by `NFIXF`. Storage-organ demand and new-growth demand are not
silently imported from WOFOST81. Literal-source qualification is required
against `SWAP/wofostnut.f90` from the pinned B1.11 authority bundle.

This policy is a crop-N input calculation only. It does not establish Soil-N
supply, full-season crop-N limitation or nonzero production admission until the
crop/Soil-N exchange owner is bound and qualified.

## Aquifer exclusion

The historical aquifer correction prerequisite is retained in the original
preregistration inside `MC_NUT_SOL_STATUS.json`. Current trajectory3 and surface
routes exclude aquifer mutation, and the programme master records aquifer as
REJECTED. This component adds no aquifer implementation or correction authority.

## Mass contract

For every candidate step, the owner exposes an independent constituent receipt:

`candidate storage = committed storage + external inputs - external outputs + internal transformations`.

Internal transfers between dissolved/sorbed or organic/mineral pools cancel in
the whole-system total. Fixation and amendments are external N inputs;
denitrification, volatilisation, exported drainage/bottom/runoff and crop
harvest/losses are external outputs according to the capability contract.

Whole-system qualification must check the sum across all active stores,
separately from local equation oracles. Restart must serialize every persistent
store required to reproduce the next accepted step.

## Claim ceiling

This record establishes owner and mass-contract sequencing and preregisters the
separate B1.11 fixation policy. It does not yet close organic pools, mineral
pools, reactions, crop exchange, management additions, sorption, decay, pond,
aquifer or age-tracer production admission.

## Component qualification and preservation

593 independent input vectors retain the original six cases and cover strict
DVS/RELTR next-representable boundaries, zero/complete NFIXF partition, differing
vegetative deficits and ignored storage-organ demand. All three literal demand,
fixation and soil-request outputs match binary64 bits at O0/O2. The original
expanded preimage's157 one/few-ulp algebra-order differences are retained; the
port now preserves the literal addition and partition order.39 nonfinite/domain
inputs reject with cleared results under IEEE invalid/zero/overflow traps.

The original WOFOST81 nitrogen1806-case numerical oracle and edge owner pass
freshly at both optimizations. The exact source guard permits only this added,
unused production module; an explicit owner-dispatch island reconstructs the
entire incumbent F-CI workflow byte-for-byte. The original canonical hydraulic,
root and application evidence proof runs unchanged at its immutable baseline.
None of those inherited gates is relabelled as production admission of this
source policy. A future crop/Soil-N binding must select the policy explicitly,
qualify the real accepted mass/state and restart, and book fixation exactly once.

Exact inputs, outputs, retained differences, source pins and selection are in
`MC_NUT_SOL_STATUS.json`, field `component_closeout_20261016`.
