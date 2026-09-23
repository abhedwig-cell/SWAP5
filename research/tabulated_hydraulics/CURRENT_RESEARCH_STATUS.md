# TAB-HYD current research status

Date: 2026-09-23

Status: **K0 RESEARCH CLOSED / PRODUCTION HANDOFF ACTIVE / SCALE40 SUPPLEMENT PENDING**

This file is the current navigation authority for the TAB-HYD research branch. Older long-form status and experiment records remain evidence for their recorded phase but do not override this summary.

## Canonical and ownership

Current canonical at latest reconciliation:

`integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`

Research branch:

`research/tabulated-hydraulics-characterization`

Production implementation is separately owned on:

`work/f-tab02-generated-k0-provider`

Do not implement production changes from this research branch.

## K0 research conclusion

The generated typed K0 acceleration hypothesis is supported.

Qualified research representation:

- generated from the admitted default MvG parameter authority;
- 400 rows;
- raw pressure head as interpolation coordinate;
- log(K) ordinate;
- TSPACK preprocessing;
- explicit wet theta/C continuation;
- explicit Ksat plateau;
- bounds-safe lookup;
- immutable preprocessing outside the solve hot loop.

Research evidence establishes:

- bounded constitutive fidelity;
- five-profile K0 transfer fidelity;
- typed provider acceleration;
- current-canonical Reference-Richards compatibility;
- transaction/mass compatibility in bounded fixtures;
- temporal-certificate compatibility;
- timestep-context capability;
- bounded F-SI39/KSATEXM research handoff.

Controlling closeout:

`RESEARCH_CLOSEOUT_20260923.md`

## Typed acceleration evidence

Research-only typed provider and solver experiments show that the legacy scalar-wrapper parity result was not the right architecture-level performance measure.

Current-canonical four-node Reference-Richards integration run:

`35879637410`

Result:

- all five bounded cases PASS;
- equal nonlinear iteration counts route-by-route;
- equal linear-solve counts;
- mass differences around machine precision;
- repeated solve reductions approximately 28–39% in the small constitutive-heavy fixture.

These percentages are research-fixture characterization only.

## Production handoff live state

See:

`LIVE_HANDOFF_STATUS_20260923.md`

The separately owned F-TAB02 production branch has already qualified A–E and a dedicated G gate. Sequential A→E→G preservation remains the current production sequencing boundary at the latest observed state.

The historical external blocker about unavailable exact SWAP 4.3.1 archive bytes is obsolete for live handoff: the production work unit has materialized and verified the exact authorized archive.

Production evidence has reproduced the acceleration sign with smaller, more realistic bounded percentages than the research microbenchmarks.

## K1 disposition

K1 is separate and does not block K0.

Controlling diagnostic:

`K1_ROUTE_CENSUS_RESULT.md`

Run:

`35879745205`

Result:

- coarse_dry_free: analytical/raw/raw+capacity all complete;
- coarse_dry_pulse: all three complete;
- loam_mid_free: all three exceed 120 s;
- clay_wet_free: all three exceed 120 s;
- loam_capillary: all three exceed 120 s.

Therefore:

**K1_REFERENCE_ENVELOPE_RUNTIME_BLOCKED / NOT_TABLE_FALSIFIED / OUTSIDE K0 HANDOFF**

Do not infer broad K1 fidelity or production readiness.

## Generic legacy tables

The historical `SWSOPHY=1` machinery is not the production target.

Research established that:

- the historical interpolation machinery can be accurate;
- the old scalar lookup route has avoidable overhead;
- table endpoint derivative semantics contain a real historical defect;
- one public BOFEK/Staring table is incompatible with the current monotonicity contract;
- current typed production does not admit generic user-supplied tables.

Generic external tabulated hydraulics is a separate future capability.

## Supplemental 40-node scale gate

Purpose:

check whether the typed K0 acceleration remains visible when the Reference-Richards fixture grows from 4 to 40 nodes.

Preregistration:

`TYPED_REFERENCE_RICHARDS_SCALE40_PREREGISTRATION.md`

Current rerun:

`35882147418`

Earlier failures were technical harness failures before model evaluation. The repaired harness now:

- uses a valid 40-node grid stub;
- writes/reads scenario identity consistently;
- compiles the actual 40-node program;
- initializes analytical and generated routes with provider-consistent water contents;
- applies prospective fidelity, mass and iteration gates.

This scale gate is supplemental. It does not reopen K0 research closure.

## Next safe action

1. Read run `35882147418`.
2. Classify it as:
   - SCALE_PASS,
   - PERFORMANCE_SCALE_LIMIT, or
   - SCIENTIFIC_SCALE_GATE_FAILURE.
3. Persist the scale result.
4. Do not tune representation parameters in response to timing alone.
5. Keep production admission and F-TAB02 sequencing in the production workstream.
