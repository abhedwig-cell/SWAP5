# TAB-HYD typed Reference Richards scale40 preregistration

Date: 2026-09-23

Status: **PREREGISTERED SUPPLEMENTAL RESEARCH SCALE GATE**

## Purpose

Test whether the generated raw-head400 K0 provider remains scientifically equivalent and materially cheaper when the current-canonical Reference Richards fixture is enlarged from 4 to 40 vertical nodes.

This gate is supplemental research characterization. It does not reopen the already closed K0 representation research and does not replace F-TAB02 production qualification.

## Authority

- canonical source pinned by workflow: `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`;
- analytical provider: current canonical `b110_default_mvg_provider_t`;
- table candidate: research `tabhyd_raw_provider_t`;
- solver: current Reference Richards typed seam;
- table representation: bounds-safe raw-head400, log(K), explicit wet theta/C branch, explicit Ksat plateau.

## Harness

Five existing TAB-HYD hydraulic scenarios are expanded to 40 nodes:

- coarse_dry_free;
- loam_mid_free;
- clay_wet_free;
- coarse_dry_pulse;
- loam_capillary.

The upper 20 nodes use the scenario topsoil material and the lower 20 nodes the scenario subsoil material.

Both analytical and generated routes must start from the same pressure-head field but from **provider-consistent water content**.

No solver tolerance, branch threshold, table density or physical forcing may be tuned after seeing the result.

## Scientific acceptance gates

For each scenario:

1. analytical route converges;
2. table route converges;
3. nonlinear iteration counts are identical;
4. max absolute head difference <= `5e-2 cm`;
5. head RMSE <= `1e-2 cm`;
6. max absolute water-content difference <= `2e-2`;
7. both integrated mass-balance residuals <= `1e-8 cm` in absolute value.

These reuse the previously established TAB-HYD bounded fidelity scale and do not depend on the timing result.

## Performance characterization

The two routes are timed in balanced alternating order over repeated solves.

Report:

- analytical median;
- table median;
- table delta percentage.

There is **no minimum speedup acceptance threshold**.

Interpretation rules:

- consistent negative delta: scaling evidence that the local acceleration survives at 40 nodes;
- near-zero delta: runtime parity at this scale;
- positive delta: a scale-dependent performance limit to characterize, not automatic scientific failure.

No whole-SWAP or portable production percentage may be inferred directly.

## Failure classification

A compile, fixture or harness defect is **TECHNICAL_HARNESS_FAILURE** and is repaired without scientific interpretation.

A convergence/fidelity/mass failure after successful harness execution is **SCIENTIFIC_SCALE_GATE_FAILURE** and must be analyzed before making broader scale claims.

A timing regression with scientific gates green is **PERFORMANCE_SCALE_LIMIT**, not a physics failure.

## Nonclaims

This gate does not admit:

- production provider selection;
- generic user tables;
- legacy SWSOPHY=1;
- SWKIMPL=1;
- KSATEXM outside its separately qualified bounded extension;
- whole-Hupsel equivalence;
- MultiSWAP speedup.
