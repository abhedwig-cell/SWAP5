# F-MIG431-INT12-P0 preregistration

Date: 2026-10-01

Status: PREREGISTERED
Branch: `work/f-mig431-int12-p0-aggregate-runtime`
Pinned canonical base: `8bb835a065248aad06b18a3b563234b20033ba0d`

## Goal

Define and, only if necessary, implement the single shared runtime seam required by legacy `SWINTER=1` and `SWINTER=2`: immutable source-window aggregate provenance, deterministic apportionment to numerical subspans, accepted progress, rollback and restart.

This work unit does not implement the Von Hoyningen-Hune/Braden or Gash scientific equations. Those remain sibling work units after this seam is qualified/admitted or proven unnecessary.

## Authority

Read before substantive work:

1. live `AGENTS.md` on `integration/f-ci-canonical`;
2. live canonical head and reconcile delta from the pinned base;
3. `docs/audits/PPA_WU04_STATEFUL_ET_INTERCEPTION_SCIENTIFIC_REVIEW.md`;
4. `integration/audits/PPA_WU04_STATEFUL_ET_INTERCEPTION_CONTRACT.json`;
5. PPA-WU03 forcing/application authority;
6. current transaction/restart and mass-ledger authority.

## Frozen semantics

For SWINTER=1/2:

- there is no persistent physical canopy-water storage;
- `aintc` is a source-window aggregate, not storage;
- a smaller hydraulic retry must not become a new scientific interception window;
- rejected trials may not advance accepted aggregate progress;
- restart inside a source window must neither duplicate nor lose aggregate;
- actual accepted water accounting must remain with existing accepted mass owners.

## Owned scope

- typed source-window identity and immutable provenance;
- deterministic aggregate apportionment contract;
- accepted-progress receipt/state if truly required;
- restart payload for partially consumed source windows;
- rollback/retry behavior;
- a method-neutral interface consumed later by SWINTER=1 and SWINTER=2 equation providers.

Prefer a stateless/recomputable design where possible. Persistent continuation is admitted only where needed to preserve accepted progress across restart.

## Forbidden shared mutations

Do not modify without a separate prerequisite:

- hydraulic timestep selection;
- Richards solver ABI;
- actual evaporation owner;
- root-water uptake owner;
- crop owner state;
- Rutter SWINTER=3 state/semantics;
- snow state;
- FMR commit policy;
- generic mass ledger semantics;
- meteorological file/calendar parser;
- method-specific SWINTER=1 or SWINTER=2 equations.

## Falsification question

The preferred hypothesis is:

> one small method-neutral source-window/progress seam is sufficient for both SWINTER=1 and SWINTER=2 without creating a new physical process-state owner.

Attempt to falsify this. If current canonical forcing/restart infrastructure already provides the necessary semantics, do not add a duplicate runtime layer. Record the seam as already satisfied and route C/D directly to existing authority.

## Acceptance gates

Before any method-specific sibling starts:

- source-window identity survives arbitrary numerical partitioning;
- accepted apportioned fractions sum to the frozen aggregate within representation tolerance;
- rejected trial produces zero accepted-progress mutation;
- failed-then-accepted retry is equivalent to direct accepted retry from the same checkpoint;
- mid-window restart neither duplicates nor loses aggregate;
- A/B/A replay deterministic;
- O0/O2 identity;
- no mass entry for provenance/progress state itself;
- PPA-WU01/PPA-WU03 and Rutter preservation;
- no hidden calendar-day kernel state;
- explicit result whether a new production runtime mutation was necessary.

## Successor split

After P0 closure:

- `F-MIG431-INT12-C`: SWINTER=1 Von Hoyningen-Hune/Braden independent B1.11 equation oracle and production provider.
- `F-MIG431-INT12-D`: SWINTER=2 Gash independent B1.11 equation oracle and production provider.

C and D may run in parallel only after they consume the same admitted/frozen P0 seam and neither changes it.

## Stop conditions

Stop only at:

- qualified/admitted shared seam;
- explicit proof that existing canonical infrastructure already satisfies the seam;
- explicit falsification requiring a different architecture;
- or a real shared-authority blocker.
