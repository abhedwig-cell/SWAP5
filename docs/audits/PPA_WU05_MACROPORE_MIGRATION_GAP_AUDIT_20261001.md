# PPA-WU05 macropore migration gap audit — SWAP 4.3.1 to current SWAP5

Date: 2026-10-01

Status: `CURRENT_CANONICAL_GAP_AUDIT`

Pinned canonical authority:
`integration/f-ci-canonical@ae3c7a9ba4a9ab741992be965448cf633820d2a1`.

This audit answers one question: which SWAP 4.3.1 macropore capabilities are already
represented by canonically admitted SWAP5 production behavior, and which materially
relevant migration gaps remain?

It does not change the frozen Status-A denominator.

## Classification

- **ADMITTED**: production behavior is canonically admitted and qualified in the named bounded envelope.
- **PARTIAL**: an important bounded form is admitted, but 4.3.1 exposes a wider configuration/interaction envelope.
- **PRIMITIVES_ONLY**: source/process primitives are qualified, but the complete live production composition is not.
- **MISSING**: no current canonical production owner was found for the 4.3.1 capability.
- **SEPARATE_MODEL**: RFM development is not a direct claim of 4.3.1 standard-macropore equivalence.

## Standard SWAP 4.3.1 macropore route

| Capability | Current state | Authority / boundary |
| --- | --- | --- |
| Standard macropore state/storage and multi-domain bookkeeping | ADMITTED | A8/A9/A10 production route; candidate/commit/restart ownership qualified. |
| Surface-connected rain/irrigation/melt entry | ADMITTED | A9 source-faithful explicit top-input carrier. |
| Lateral overland/infiltration-excess macropore receipt | ADMITTED | A9 explicit separately owned lateral receipt; it is deliberately not inferred from generic top flux. |
| Top inflow capacity limitation, redistribution and returned surface receipt | ADMITTED | Existing A6 logic composed into A8/A9 runtime. |
| Unsaturated matrix absorption / sorptivity exchange | ADMITTED | A6 rate bundle and A15 derivative authority, composed into the standard runtime. |
| Saturated matrix/macropore exchange | ADMITTED | A6 saturated exchange and sources. |
| Perched/schijngrondwater detection and exchange | ADMITTED | PERCH21; source-backed Andelst authority, inner Reference-Richards exchange and exact FrReduQ retry continuation. |
| Exchange derivative in Richards Jacobian | ADMITTED | A15/PERCH chain; source-faithful derivative semantics. |
| Source FrReduQ retry/recovery semantics | ADMITTED | PERCH19/PERCH20/PERCH21, factors 1, 0.1, 0.01, 0.001 with transactional restart semantics. |
| Main-domain rapid drainage | PARTIAL | A10 admits one main-domain drain, boundary-aligned level, source-faithful A6 RAPIDDRAIN and exactly-once external mass ownership. |
| Arbitrary rapid-drain level within a compartment | MISSING | A10 deliberately fails closed for this geometry. |
| Multiple rapid-drain levels | MISSING | Outside A10 admitted envelope. |
| Covering-layer macropore route, including `IcTopMp > 1` | MISSING | A9 explicitly fails closed; no current canonical production owner found. |
| Dynamic shrinkage/crack-geometry feedback | MISSING | A8/A10 explicitly exclude within-corrector dynamic crack-geometry displacement feedback; no current canonical production owner found. |
| Ponding/runon as independent direct macropore source components | MISSING/PARTIAL | A9 does not admit these as independent direct macropore sources. Existing returned-surface bookkeeping is not equivalent to a general ponding/runon source owner. |
| Simultaneous macropore top-input ownership with Snow/Black/Boesten/fixed-weir surface routes | MISSING COMPOSITION | A9 deliberately excludes these ownership combinations. |
| Rapid-drain receipt owned by fixed-weir/Ribasim surface water | MISSING COMPOSITION | A10 deliberately excludes shared ownership of the same receipt. |
| RossFast macropore execution | MISSING | Standard admitted macropore production route remains Reference Richards. |
| Parallel/concurrent MultiSWAP macropore execution | MISSING | Current macropore qualification is serialized single-column. |
| Full official 4.3.1 macropore case end-to-end equivalence | NOT YET ESTABLISHED | A18/PERCH use official Andelst source/profile authority and a source-backed perched state, but this is not a claim that every output of the complete unmodified 4.3.1 macropore application has been reproduced end-to-end by SWAP5. |

## RFM line

The RFM line must not be counted as automatic completion of the SWAP 4.3.1 standard
macropore denominator. It is a separate reduced/alternative preferential-flow model.

Canonical already contains qualified RFM components for:

- unponded activation and source partition;
- hydraulic/sorptivity binding;
- surface-event age;
- matrix-share rebinding;
- preferential routing;
- dedicated physical state and optional-state carrier;
- endpoint release;
- MB deep-path fate;
- whole-column ledger;
- real-Richards split source binding;
- runtime orchestrator;
- wall-history ownership;
- IC storage geometry;
- hydrostatic IC macropore head.

However, the historical A26 dispatch record was blocked before live backend composition.
A26H/A26I/A26J/A26K resolve important physical ownership prerequisites, but this audit finds
no later canonical closeout proving the complete RFM backend dispatch and removal/replacement
of the A20 fail-closed runtime guard. Therefore:

`RFM_COMPLETE_LIVE_BACKEND = NOT YET ESTABLISHED_BY_CURRENT_AUDIT`.

That is a separate RFM completion item, not a blocker to calling the bounded standard
PERCH21 route admitted.

## Remaining migration programme, ordered by dependency

### M1 — covering-layer standard macropore physics

Recover exact 4.3.1 source semantics for `IcTopMp > 1`, including top-source routing,
geometry, storage/exchange implications and restart state. Build a source-backed fixture and
admit it without weakening the existing A9 surface-owner contract.

### M2 — dynamic shrinkage/crack geometry

Audit the 4.3.1 geometry update path and identify which crack/shrinkage variables are true
physical state versus derived geometry. Qualify accepted-state update timing, reject isolation,
restart and its interaction with matrix/macropore exchange. Do not approximate this as a
within-Newton mutation unless source authority requires it.

### M3 — complete rapid-drain geometry

Extend A10 only if 4.3.1 application requirements justify it:
- within-compartment drain levels;
- multiple rapid-drain levels;
- explicit receiving-water ownership.

Keep the already qualified single aligned main-domain route unchanged.

### M4 — surface-owner combinations

Define explicit ownership/composition contracts for macropore top input with:
- Snow;
- Black/Boesten evaporation;
- ponding/runon;
- fixed-weir or external Ribasim surface water.

Do not infer source components from generic top flux.

### M5 — full official-case equivalence matrix

Use official SWAP 4.3.1 macropore cases and selected source-backed events to compare:
- accepted matrix state;
- macropore storage/state;
- top input and returned receipt;
- matrix/macropore exchange;
- rapid drainage;
- perched topology where active;
- whole-column water balance;
- restart/replay.

This is the gate needed before claiming broad SWAP 4.3.1 macropore migration completion.

### M6 — execution-envelope expansion

Only after the physical migration denominator is closed, decide separately whether product
requirements require:
- RossFast macropore execution;
- parallel/concurrent MultiSWAP;
- broader coupled surface-water combinations.

These are production/execution expansions and must not be confused with proof that the
4.3.1 physics denominator has been migrated.

### R1 — complete RFM live backend

Resume the separate A26/RFM dispatch line using A26H-J-K as prerequisites. Prove full
candidate/commit/reject/restart and whole-column closure before replacing the fail-closed
RFM backend guard.

## Recommended immediate next workunit

`PPA-WU05-MIGMAC01 — covering-layer source reconciliation and authority fixture`.

Reason: covering-layer behavior is an explicit known hole in the standard 4.3.1 migration
surface, is currently fail-closed rather than ambiguously implemented, and can be isolated
without reopening the now-closed PERCH21 route.

In parallel, a non-mutating source audit may preregister M2 dynamic shrinkage/crack geometry,
but M1 should own the next implementation branch.

## Current conclusion

The difficult perched matrix/macropore exchange problem is closed and canonically admitted.
The standard macropore migration is therefore no longer blocked on its core inner-Richards
exchange mechanism.

Broad 4.3.1 macropore migration is **not yet complete**. The remaining standard-model gaps
are now bounded primarily to covering-layer behavior, dynamic crack/shrinkage geometry,
the wider rapid-drain envelope, surface-owner combinations and final official-case
equivalence. RFM completion remains a separate line.

## Later canonical reconciliation: MIGMAC05 (2026-10-05)

The earlier gap census above is historical. MIGMAC01 covering-layer and
MIGMAC02/03/04 dynamic constitutive/preparation admissions are followed by
MIGMAC05 PR #1022 mixed Kim/peat/rigid Reference qualification. The mixed-law
runtime gap is closed within the serialized admitted chain, including retry,
restart and wetting water displacement. No production source changed here.

New mixed-law rapid-drain reference KD construction, wider multiple/within-cell
drains, additional surface owners and final whole-model case equivalence remain
outside this admission. Broad 4.3.1 macropore migration is still incomplete.
Controlling bounded authority: [MIGMAC05 closeout](PPA_WU05_MIGMAC05_CLOSEOUT.md).
