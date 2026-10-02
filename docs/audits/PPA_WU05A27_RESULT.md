# PPA-WU05-A27 result: first falsified replacement route

Current continuation authority (2026-10-02): [bounded cohort frontier](PPA_WU05A27_BOUNDED_COHORT_RESULT.md) and `PPA_WU05A27_STATUS.json`. Sixteen cohorts/node pass the finite research screen; physical closure and full production A/B/C remain open. The initial negative result below is retained as its historical process-scope finding.

Date: 2026-10-01
Status: PARTIAL_NEGATIVE_RESULT; A27 full benchmark remains OPEN
Reconciled canonical: 19f09b818b1bb30c1428919074c00098dbd062bd
Initial A27 head: 6c38f7f015553bf4c155a7efb1d8fb11b189e804
Tested source postimage: 36a2ea9a46b80d014f64b472c31bae40c3f71572
Execution: local GNU Fortran 13.3.0, O0/O2, fcheck=all.
No GitHub Actions run was requested.

## Finding and scope

The current RFM route cannot represent saturated matrix-to-macropore exchange.
This falsifies the proposal to use this route as a process-equivalent replacement
where that exchange is required. It does NOT establish a whole-column error
magnitude, an E3 divergence, or that RFM is unsuitable in all wet profiles.

The directional difference has an identified conceptual cause (E2-type process
difference). Full-case E0/E1/E2/E3 classifications remain unassigned.

## Exact reproducible experiment

Run:
    FC=gfortran bash tests/fpm/run_ppa_wu05a27_reverse_exchange.sh

One local contact at depth 95 cm, thickness 10 cm. Macropore water level at
94 cm depth, giving macropore pressure head +1 cm. RFM endpoint bottom 100 cm,
contact 90..100 cm, explicit area fraction 0.05, storage 0.3 cm:
H=W/a=6 cm; water level depth=100-6=94 cm.

Matrix pressure heads: +2, +5, +10 cm.
Timestep durations: 0.01, 0.005, 0.0025 day.
Standard exchange: one domain, fully saturated contact, no partial-cell
correction, flow reduction 1, reciprocal conductance cdarcy=0.01 /day,
horizontal conductivity 1 cm/day, diameter 20 cm.
RFM: conductivity 1 cm/day, exchange length 20 cm, chi_wall=1,
zero sorptivity for this saturated local contact, wall age zero.

The local state is deliberately held fixed. This is a directional process
oracle, NOT a time-integrated column simulation or a timestep-convergence study.
It does not need an atmospheric or bottom boundary, because neither is invoked.

Independent Darcy expectation:
    matrix_to_macro_amount = cdarcy * (h_matrix-h_macro) * dt

Both optimization levels produce identical CSV output. All nine standard
amounts satisfy the analytic oracle within 1e-14 cm. RFM emits no reverse
exchange and leaves endpoint storage unchanged. At dt=0.01 day the standard
amounts are 0.0001, 0.0004 and 0.0009 cm respectively.
The proportional timestep sweep establishes an instantaneous directional
difference that does not disappear by reducing dt. It does not establish
accumulated error over repeated evolving steps.

Raw evidence: evidence/PPA_WU05A27_REVERSE_EXCHANGE.csv.

## Source-backed attribution

- mod_ppa_wu05a6_saturated_exchange_rate evaluates both exchange directions.
- mod_ppa_wu05a6_saturated_sources retains matrix-to-macro rates.
- mod_ppa_wu05a6_rate_bundle includes those rates in net matrix exchange.
- mod_rfm_ic_hydrostatic_head clamps the macro-to-matrix head difference to
  max(0,h_mp-h_matrix).
- mod_rfm_endpoint_release only releases accepted macro storage to the matrix.
- mod_rfm_production_candidate_composer publishes nonnegative matrix sources.
- mod_rfm_matrix_source_provider rejects negative RFM source rates.

The comparator is not assumed ground truth. The positive standard direction
also agrees with the local Darcy gradient for a hydraulically connected
saturated contact. Whether this process matters in a particular field case
still needs column-scale evidence. No coefficient was calibrated to shrink
the difference. Standard cdarcy and RFM wall coefficients are not claimed to
have an exact magnitude mapping.

Additional local preservation check on the initial A27 source:
PPA_WU05A26_ZERO_RFM_LIMIT=PASS
PPA_WU05A26_TIMESTEP_REFINEMENT=PASS
PPA_WU05A26_LIVE_TRIAL_PREPARER=PASS
Those inherited fixtures use frozen synthetic hydraulics and do not qualify
the requested full hydrologic or performance benchmark.

## Production recommendation and next work

Do not claim practical equivalence where matrix-fed preferential drainage,
saturated reverse exchange, or related interflow is physically relevant.
Also retain A26's existing exclusions: ponding/runoff and head-controlled
top boundaries are unsupported. Do not suppress these processes in comparator
B to manufacture equivalence.

Candidate benchmark envelope: unponded/runoff-free flux-controlled cases
with negligible matrix-to-macro exchange, explicit independently described
geometry, and separately recorded MB deep receipt. This envelope is a
hypothesis, NOT an A27-qualified production recommendation.

A27 remains open: paired A/B/C evolving-column harness, physical parameter
mapping, multi-soil eight-regime suite, repeated timings/counters,
hydrographs, true timestep refinement and worker scaling are not completed.
There is no speedup claim, stability claim or qualified positive frontier.

Next safe step: define physical geometries and map volume/contact/depth while
keeping intake-law uncertainty explicit; compose an A/B/C column benchmark
using the serialized production backend. Preserve excluded regimes as
negative controls. A bounded performance benchmark may proceed without
changing the admitted physics; widening the RFM exchange contract requires
separate authority.
