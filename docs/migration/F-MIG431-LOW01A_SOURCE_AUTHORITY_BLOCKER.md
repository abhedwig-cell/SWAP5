# F-MIG431-LOW01-A source-authority blocker

Date: 2026-10-01

Status: `BLOCKED_SHARED_AUTHORITY_PREREQUISITE`
Branch: `work/f-mig431-low01a-qgwl-boundary`
Preregistration: `a32a23e0af8920a8b29aeebca8ae916bdea4d9c8`
Pinned and live canonical: `8bb835a065248aad06b18a3b563234b20033ba0d`

## Reconcile

The live `integration/f-ci-canonical` head is still exactly the preregistered base. The LOW01-A branch was still exactly the preregistration commit before this checkpoint. No canonical drift requires replay.

## What is source-bound

B1.11 remains the scientific authority. The repository proves that B1.11 does not change `boundbottom.f90` from B0 and pins that member to SHA-256:

`5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e`.

The admitted PPA-WU02 source-bound inventory establishes for SWBOTB=4:

- qbot is a function of the current/profile groundwater level and is evaluated by legacy `BoundBottom` before the Richards solve;
- the law is state-dependent/lagged application semantics, not a time-only prescribed flux;
- HeadCalc consumes the resolved qbot through the already admitted generic prescribed-flux row;
- native units are cm and cm d-1;
- native `qbot > 0` is into the soil profile and `qbot < 0` is out;
- the two legacy control families are an exponential q(gwl) relation and an HTAB/QTAB q(h) table.

The current SWAP5 transaction authority also shows that accepted groundwater level is computed after the physical solve and saved/restored with the soil-water state. That is consistent with a lagged pre-solve provider, but it is not sufficient by itself to prove the exact B1.11 sampling statement or all retry details.

## Missing exact authority required by preregistration

The repository does not contain a byte-verifiable text copy of B1.11/B0 `boundbottom.f90` or `readswap.f90`. The exact official distribution was previously restored transiently and hash-verified by F-APP03, but its raw payload was explicitly not persisted.

The PPA-WU02 narrative intentionally summarizes, rather than reproduces, the source. It is insufficient to freeze all LOW01-A requirements without inference. In particular, the following remain unproven from currently persisted exact authority:

1. the exact exponential expression, including the precise role/presence condition of COFQHC;
2. exact parser coefficient domains and selector-specific invalid-input behavior;
3. exact HTAB/QTAB cardinality, ordering/domain constraints and parser failure behavior;
4. exact AFGEN call shape for this route and therefore the complete endpoint/interpolation contract as used by SWBOTB=4;
5. the exact executable statement showing which `gwl` generation is sampled at the BoundBottom call and its placement relative to trial checkpoint/retry;
6. any selector-specific fail-closed behavior beyond the generic repository summaries.

These items are explicit preregistration requirements. Implementing them from the abbreviated audit text, from generic AFGEN behavior, from later SWAP versions, or from desired outputs would invent scientific semantics.

## Disposition

Verdict: `F_MIG431_LOW01A_BLOCKED_MISSING_EXACT_B111_LOWER_BOUNDARY_SOURCE_MATERIALIZATION`.

No production, solver, ABI, mass-owner, transaction, parser, groundwater-coupling, root-uptake, macropore or oxygen source was changed. No sibling/child/repair/admission branch was created. No GitHub Actions run was started because qualification cannot legitimately begin before the exact source/timing contract is recoverable.

This is a central shared-authority prerequisite, not a reason to weaken LOW01-A qualification.

## Required central prerequisite

Materialize a binary-safe exact B0/B1.11 lower-boundary source surface, preferably from the controlling official distribution SHA-256
`2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`, and verify at minimum:

- `SWAP/boundbottom.f90` SHA-256 `5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e`;
- B1.11 `SWAP/readswap.f90` SHA-256 `e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c`;
- any exact helper source needed to establish the interpolation call semantics and caller staging.

The prerequisite may persist the exact relevant source members or a lossless, independently verifiable extraction sufficient to reconstruct every LOW01-A equation/domain/timing statement. Central F-MIG431 regie owns issuing any branch for that shared prerequisite.

## Resume boundary

After the shared authority prerequisite is admitted, resume this same LOW01-A branch by reconciling live canonical, freeze the exact state/timing contract before production implementation, then implement only the typed q(gwl) provider and bounded binding to the existing qbot route and execute the preregistered qualification gates.

No claim is made that any other lower-boundary functionality is migrated.
