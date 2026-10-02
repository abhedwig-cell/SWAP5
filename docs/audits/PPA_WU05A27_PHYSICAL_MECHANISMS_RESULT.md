# A27 physical mechanism frontier

Date: 2026-10-02. Status: LOCAL_RESEARCH_EVIDENCE; production A/B/C remains OPEN; no canonical admission.

Canonical reconciliation:0d44f0195c94a9732c67b5e77f2148912df9bbc8. Later delta fromc240a3c1 adds only LOW03 bottom-row composition evidence/classification; no source, shared contract, AGENTS or Status-A change. The delta from27b271c2 concerns LOW03/LOWGWL control/research, not A27 dependencies or admitted execution. Preregistration: [mechanism contract](PPA_WU05A27_PHYSICAL_MECHANISMS_CONTRACT.md). Executed code:467d734fbe8b5ea350a43e0fbf73ee412cda38cc. No production code or ownership boundary changed.

## Theory, source and reference distinctions

The [SWAP manual](https://swap.wur.nl/manual/06_macropore_flow.html), equations6.42-6.53, describes square-root contact age, a moisture-corrected active sorptivity, alternative diffusivity closure, and signed saturated Darcy. Original hash-controlled macrorate ABSORPTION and macropore MACROSTATE agree on the important distinction: stored seed remains frozen, but active sorptivity is recomputed from reference moisture minus actual moisture. They choose the larger of capillary absorption and Darcy, not their sum. History/reference moisture advance separately; dry, saturated or ended events reset history. These are standard behavioral policies, not independent proof that instantaneous dry reset is physically exact.

Philip1957 and Greco/Hendriks/Hamminga proceedings citation metadata were located, but full original texts were not verified. The primary [Gerke/van Genuchten1993 publisher abstract](https://agupubs.onlinelibrary.wiley.com/doi/10.1029/92WR02467) supports head-difference exchange with geometry/interface-conductivity dependence; its complete derivation and the1996 follow-up were not retrieved. The manual and executable sources support this bounded comparison; do not claim that the original RFM theory has been fully reconstructed.

The independent slab uses constant diffusivity and a prescribed wet/no-flow wall, with exact-in-time discrete propagation. It tests memory and feedback mechanisms, not nonlinear Richards, standard production equivalence, rainfall partition or field validity. Its semi-infinite scalar comparators are diagnostics without parameter calibration.

## Completed probes

Actual standard modules passed algebra, seed preservation, accepted-history immutability, replay, reset/reseed and both exchange signs at O0/O2 with identical output and runtime checks. At fixed age1day, seed2 and reference moisture0.45, raising theta from0.25 to0.35 halves uptake from0.195235392681 to0.0976176963403cm; frozen-seed uptake remains0.195235392681cm. In the independent constant-D slab, the accounted external pulse reduces subsequent uptake to exactly0.75 of the unpulsed response, as predicted by linearity. This isolates missing feedback in the frozen diagnostic; it does not qualify a particular nonlinear correction.

The first256/512 mesh screen failed:0.000283297034644cm versus the preregistered0.0001cm limit. Its traceback is retained. A prospective addendum added1024/2048 cells without changing the limit or mechanism parameters. The completed finest reference has analytic uptake error5.94472980842e-7cm and1024/2048 rewet difference1.62305298822e-5cm. Dry no-flow mass change is at most6.88468379528e-16cm. All initial mesh observations remain in the refinement table.

After wetting0.2day, the following2048-cell results use renewed contact0.001day. All rows have the same mean theta0.239894198317 and conserve matrix water during interruption.

| Dry gap day | Retained-profile uptake cm | Homogenized same-mean uptake cm | Scalar reset uptake cm |
| --- | --- | --- | --- |
|0.001|0.001627518438|0.023704367408|0.023707900951|
|0.01|0.004074915450|0.023704367408|0.023707900951|
|0.1|0.011079707596|0.023704367408|0.023707900951|
|0.5|0.018084504820|0.023704367408|0.023707900951|

Across all finest-grid gap/renewal cases the scalar-reset/reference ratio is1.3073 to17.3368. Spatial relaxation persists through no-loss contact interruption; mean moisture plus an immediately reset clock cannot reconstruct this exact response. Retaining the old clock alone also misses the relaxation. This falsifies exact instantaneous reset only for the prescribed no-loss diffusion hypothesis. Evaporation, different boundary conditions, nonlinear diffusivity and approximate production accuracy remain untested.

Pressure reversal requires both signs in these cases: the matrix pulse reverses the head difference, and one-sided exchange misses the subsequent return. In the two-storage linear diagnostic, let kappa=g*(1/C_matrix+1/C_macro). Explicit head difference advances by1-kappa*dt, so no-overshoot requires kappa*dt<=1 and linear stability requires<=2. These conditions follow from this model, not a universal production CFL rule.

| Execution policy | Maximum macro-head error cm | Maximum cumulative-exchange error cm | Maximum overshoots per case |
| --- | --- | --- | --- |
|Accepted-origin explicit|33.426189|1.67130945|8|
|Backward coupled|0.680430|0.03402150|0|
|Explicit subcycling, kappa*subdt<=0.1|0.067414|0.00337068|0|
|One-sided explicit|9.773811|0.48869055|1|

Errors are against exact exponential exchange at matching times over all declared cases. Conservative ledgers pass even when explicit trajectories overshoot, demonstrating that mass conservation alone does not establish stability or accuracy. Negative head excursions are also retained in raw output. At Ks0.025, coarse explicit maximum head error is0.000436791cm; at Ks5,dt0.5 it is33.426189cm. Thus the problem is regime and timestep dependent. Backward coupling and subcycling remove overshoot here but retain finite timestep error. Exact conservative linear integration is another valid option in this diagnostic. No universal requirement for nonlinear iteration or monolithic Richards coupling follows.

## Route decision and production boundary

**Route falsification, bounded:** frozen active sorptivity plus scalar dry reset is not an exact physical closure for the tested mechanisms. The earlier16-cohort screen pass remains valid against its exact research-cohort comparator, but both representations inherit the same physical assumptions; that pass cannot validate those assumptions.

**Proposed next route:** retain continuous moisture feedback and signed exchange, and investigate a bounded lateral moisture/profile state that relaxes while wall contact is absent. A fixed spatial/modal approximation is a candidate, not an implemented or qualified production state. Test variable diffusivity/retention, external moisture receipts, moving wetted geometry and physically specified drying boundaries before choosing it. An approximate reset can only be retained with an explicit drying hypothesis and measured error envelope. Separate this physical closure from numerical choices such as subcycling, conservative integrated exchange or coupled solves.

Production A/B/C remains OPEN. The present evidence establishes no speedup, broad stability improvement, E1 envelope, MultiSWAP scaling or production equivalence. Required work still includes the original eight forcing regimes, multiple defensible geometries, explicit parameter mapping, E0/E1/E2/E3 classification, difficult timestep refinement, solver counters, timing repetitions and multi-column scaling. Standard SWAP remains a behavioral comparator. Central regie retains admission; A26's accepted-state-frozen first-order split remains unchanged.

## Reproduction and durable evidence

At the executed SHA:

```bash
FC=/tmp/top03-bin/gfortran bash research/rfm/a27/run_physical_mechanisms.sh
python3 research/rfm/a27/probe_physical_mechanisms.py /tmp/a27-physical
```

Regenerate comparison/refinement tables with the persisted analysis script:

```bash
python3 research/rfm/a27/analyze_physical_mechanisms.py /tmp/a27-physical
```

The mechanism manifest under docs/audits/evidence records exact run SHAs, SHA256 dependency contents read at those SHAs, environment versions, output hashes and split archive hashes. Concatenate PHYSICAL_MECHANISMS.tar.gz.part-* in lexical order and extract the gzip tar. It contains all raw CSVs, selected full2048-cell profiles, source output, failed traceback, summary and per-case comparison/refinement tables. Source/module checks and independent-reference gates are locally qualified only for this research scope. Documentation checks are recorded separately in the verification record.
