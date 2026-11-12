# F-WOF-EXT01: matched native GLAIEX causal intervention, 2026-10-17

**RESEARCH-ONLY bounded PASS; no production admission or canonical merge.**

## Execution and provenance

- Original native O0/O2 matched input diagnostic: [run 39058395486](https://github.com/abhedwig-cell/SWAP5/actions/runs/39058395486), 60 transitions, 61 rows; native outputs mutually byte identical but cross-language differences.
- Controlled intervention: commit `80d560debc87d6cf38f272e0f12bfb12a99400ec`, [run 39059061721](https://github.com/abhedwig-cell/SWAP5/actions/runs/39059061721), completed SUCCESS for both `protocol-probe` and `native-fortran`.
- Same pinned Spring_barley_301 source, meteorology, synthetic external water-stress ratio 0.5, 60-day forcing and PCSE reference. The workflow copies `src/crop/mod_wofost_finalize_rates.f90` into an ephemeral build file; admitted Fortran production source **was not edited**.
- Only change to temporary Fortran arithmetic: multiplication by RFTRA in `GLAIEX` is limited to the juvenile conditional `DVS<0.2 && LAI<0.75`, matching `pcse/crop/leaf_dynamics.py` `WOFOST_Leaf_Dynamics_N` condition. Subsequent N-growth rate correction still applies RFRGRL within the juvenile condition.

## Quantitative A/B result

Before intervention: Python-vs-Fortran first LAI fork output row 21 (2010-05-06), signed delta -0.0004639948884571643; first TAGP fork row 22. End TAGP Fortran 360.35137145341423 vs PCSE 533.5071863311674 kg/ha (delta -173.1558148777532); cumulative N difference -4.933043744568067 kg N/ha.

After intervention:
- All **twelve** compared crop-owned output fields match for **all 61 observations to 1e-12 absolute**; `first_difference_above_1e_minus_12=null` for each.
- Worst nonzero absolute residual: `TWST = 2.7755575615628914e-17`, an expected floating-point rounding-level residual.
- Final TAGP = 533.5071863311674 kg/ha, cumulative N = 17.02901096975551 kg N/ha, and LAI = 0.6620816045638119 in **both** Python and corrected research Fortran.
- O0 and O2 native output are **byte identical**.

This A/B experiment identifies the native `GLAIEX` juvenile-stress condition as **sufficient to explain the entire previously observed twelve-variable discrepancy in this pinned barley case**. It is not a proof of general equivalence, correctness of either formulation in all regimes, or safe replacement of admitted PP01/PP02 production science.

## Architecture and next admission gates

**CONDITIONAL GO** for a daily externally owned crop-state interface and independent native research backend. **NO-GO** to production substitution now. Preserve SWAP5 hydrological accepted-state, transaction accept/reject and rollback ownership; WOFOST complete crop-state ownership; ANIMO5 soil-N as future explicitly versioned interface.

Before a candidate production change: (1) confirm scientific authority for the conditional factor against WOFOST81 source/reference, (2) test both stress and no-stress conditions, juvenile transitions and several parameterizations, (3) protect PP01/PP02 and current canonical regression gates, (4) qualify state snapshot/restore vs process replay, failed worker, deterministic retry, and actual accepted hydrological event coupling, (5) pin daily units and complete nitrogen exchange contract. Do not quietly fix admitted Fortran physics from this research result alone.
