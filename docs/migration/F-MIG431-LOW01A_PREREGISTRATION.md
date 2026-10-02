# F-MIG431-LOW01-A preregistration

Date: 2026-10-01

Status: PREREGISTERED
Branch: `work/f-mig431-low01a-qgwl-boundary`
Pinned canonical base: `8bb835a065248aad06b18a3b563234b20033ba0d`

## Goal

Migrate the SWAP 4.3.1 B1.11 `SWBOTB=4` application law: lower-boundary flux as an explicit function of profile groundwater level, without changing the already admitted generic prescribed-flux solver row.

The legacy law is source-bound by PPA-WU02. It evaluates either an exponential q(gwl) relation or the legacy q(h) table before the Richards solve. This is state-dependent application semantics and must not be represented as time-only prescribed qbot.

## Authority

Read before substantive work:

1. live `AGENTS.md` on `integration/f-ci-canonical`;
2. live canonical head and reconcile delta from the pinned base;
3. `docs/audits/PPA_WU02_SOURCE_BOUND_LOWER_BOUNDARY_ENVELOPE.md`;
4. `integration/audits/production_physics_application_envelope_gap_register.json`;
5. current lower-boundary and transaction admission evidence.

The B1.11 source/reference is scientific authority. Existing SWAP5 typed contracts and current canonical admissions are architecture authority.

## Owned scope

- typed representation of the legacy SWBOTB=4 q(gwl) law;
- exact state/timing semantics for the groundwater-level input used by that law;
- pure provider/result seam producing qbot for the already admitted generic flux row;
- bounded application binding if it can be added without widening shared ownership;
- independent source-equation tests and transaction/retry tests specific to this law.

## Forbidden shared mutations

Do not modify without splitting a separate prerequisite and returning it to central regie:

- generic Richards request/result ABI;
- generic bottom-boundary ABI semantics;
- qbot sign convention;
- accepted water-mass owner or mass ledger;
- transaction/checkpoint/commit policy;
- FMR ABI;
- groundwater datum or MODFLOW predictor/corrector semantics;
- root-water uptake;
- macropore or oxygen ownership;
- general SWP/BBC parser.

## Required scientific recovery

Freeze from B1.11 before implementation:

- exact exponential formula and coefficient domains;
- exact q(h) table interpolation semantics and endpoint behavior;
- which groundwater-level value is sampled and at what physical/trial time;
- lagging/candidate-state semantics;
- units and sign;
- fail-closed invalid parameter/table cases.

Do not infer any of these from the existence of the generic flux row.

## Acceptance gates

A production-admission candidate requires:

- exact independent B1.11 equation/table oracle;
- state/timing contract persisted before implementation;
- positive, zero and negative qbot cases where source-valid;
- table endpoints and interpolation cases;
- A/B/A deterministic replay;
- O0/O2 output identity;
- rejected-trial committed-state immutability;
- failed-then-accepted retry from the same committed state;
- accepted mass closure through the existing qbot owner;
- preservation of admitted mode 2, mode 6, mode 7 and relevant groundwater/head profiles;
- no shared ABI or ownership drift.

## Stop conditions

Stop only at:

- qualified production-admission candidate;
- canonical admission and closeout;
- explicit falsification of the proposed seam;
- or a real blocker requiring shared-authority change.

No broad claim that all lower-boundary modes are migrated follows from LOW01-A.
