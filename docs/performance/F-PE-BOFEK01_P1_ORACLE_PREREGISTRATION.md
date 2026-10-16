# F-PE-BOFEK01 P1 preregistration: independent fixed-step temporal oracle

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_P1_RESULTS`

Canonical authority: `integration/f-ci-canonical@50ee9dc2acbc9847807d3fd98d0553f9862d428b`.

## Reason for this successor study

P0 compared alternative timestep policies against the current adaptive Reference trajectory. That comparison is unsuitable as a strict temporal truth because changing the timestep sequence changes terminal head, runoff and ponding even when the candidate uses more, smaller steps. P0 gates and results remain immutable negative evidence. They are not relaxed.

P1 therefore introduces an independent refined fixed-step oracle. Candidate numerical policies are judged against this oracle, not against the current adaptive policy trajectory.

This remains a numerical-policy study on the BOFEK00-admitted fixed-K dynamic-top, `SWKIMPL=0` route. No production defaults change in P1.

## Test-bank boundary

Use the already preregistered 20-case hydraulic/regime bank in `F-PE-BOFEK01_TESTBANK.json`.

The bank contains four repository-backed hydraulic archetypes and five forcing/state regimes. It is adequate for policy mechanism screening, but the repository still lacks a full BOFEK profile catalogue. Therefore P1 cannot by itself support a BOFEK-ID-specific production mapping.

The four existing holdout cases remain untouched for parameter selection:
- B12/POND
- O14/MOIST
- O14/WET
- O14/POND

## Fixed-step oracle

For each case, disable adaptive timestep movement by setting `dtmin = dtmax = dt0`.

Use the same admitted solver formulation, BALTOL02 effective balance floor, `SWKIMPL=0`, max iterations 8 and max backtracking 8.

Primary oracle:
- `dt = 0.00025 d`, exactly 480 accepted fixed steps over 0.12 d when no final shortening is needed.

Coarser convergence witness:
- `dt = 0.0005 d`, exactly 240 accepted fixed steps.

The oracle is considered temporally resolved for a case only when 0.0005 d versus 0.00025 d satisfies all of:
- cumulative runoff difference <= `1e-4 cm`;
- terminal ponding difference <= `1e-4 cm`;
- terminal storage difference <= `1e-4 cm`;
- terminal pressure-head probes at top, middle and bottom each differ <= `1e-3 cm`;
- both runs have maximum per-step combined water-ledger residual <= `5e-8 cm`;
- neither run fails or enters a retry loop.

If any case fails this oracle-convergence gate, that case is not used to qualify a candidate. No finer oracle may be introduced without a separately committed amendment before its results are exposed.

## Candidate accuracy gate against oracle

A candidate passes a temporally resolved case only if:
- cumulative runoff difference from the 0.00025 d oracle <= `1e-4 cm`;
- terminal ponding difference <= `1e-4 cm`;
- terminal storage difference <= `1e-4 cm`;
- terminal head probes top/middle/bottom each differ <= `1e-3 cm`;
- maximum ledger <= `5e-8 cm`;
- no solver failure;
- rejected attempts <= max(2 times current-policy rejected attempts, 25% of candidate attempts).

These bounds are committed before P1 result exposure.

## P1 candidates

P0 showed no material deterministic-work advantage from timestep decrease factor, failure divisor, MAXIT, or backtracking limits. Those families do not advance to P1 interaction work.

P1 carries only:
- current adaptive Reference policy, as comparator rather than truth;
- `DTMAX_X2`;
- `DTMAX_X4`;
- `DT0_HALFMAX`;
- `DT0_MAX`;
- `HEAD_X10`;
- `HEAD_X100`.

The head-tolerance candidates remain separate from timestep candidates in this phase. No interaction is tested until at least one member of each relevant family independently passes.

## Advancement

A candidate advances from screening to holdout only if:
- it passes the oracle accuracy gate on every temporally resolved screening case;
- median deterministic work reduction relative to current adaptive Reference is >= 8%;
- it creates no new nonconvergence pathology.

A timestep candidate failing any wet/ponding screening case cannot advance.

A head-tolerance candidate may advance only if all screening cases pass and median deterministic work reduction is >= 8%.

## Holdout and timing

Only advanced candidates are evaluated on the four frozen holdouts.

Final numerical-policy qualification additionally requires:
- every temporally resolved holdout passes;
- BOFEK00 wet/ponding route remains stable;
- no dry-case regression;
- at least five paired repetitions for wall-clock confirmation;
- median paired wall-clock improvement >= 10%;
- no unexplained holdout runtime regression > 10%.

Single subprocess timings from P0 are explicitly non-authoritative because the individual runs are around millisecond scale and startup noise dominates.

## Qualification boundary

Possible P1 conclusions:
- evidence for a global numerical policy on the tested hydraulic/regime envelope;
- evidence that policy must be regime-dependent;
- no strict policy gain;
- research-only result.

A `QUALIFIED_BOFEK_CLASS_POLICY` remains unavailable until a repository-owned BOFEK catalogue or equivalent authoritative BOFEK profile mapping is present and exercised.
