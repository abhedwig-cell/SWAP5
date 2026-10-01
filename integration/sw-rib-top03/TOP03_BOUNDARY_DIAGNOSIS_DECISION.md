# TOP03 boundary diagnosis and route decision

Date: 2026-10-01
Status: QUALIFIED_BOUNDED_RESEARCH__NO_PRODUCTION_ADMISSION
Canonical inspected: 44c6df02a58edee79f88dde8ca8aadbec26337fc

## Experiment

Three geometries, three lower boundaries, three initial states, two horizons and ten temporal subdivisions produce 540 integrations per optimization for each experiment. Five experiments, O0 and O2, give 5400 isolated research integrations. All completed gates were local GNU Fortran 13.3.0; no Actions requested. Production source and temporal acceptance remained unchanged.

Geometry: original four-node 3 cm fixture with synthetic distances; same four-node depths/thicknesses with consistent face/node distances; and a synthetic 40-node 100 cm column. Lower boundary: mode 7 free drainage; mode 2 fixed bottom flux -K(initial head); mode 5 fixed bottom-face pressure at the initial uniform head. These are explicitly different physical problems, not equivalent replacements. Initial heads -123, -10 and +0.02 cm; maintained surface head and initial pond 0.02 cm. Histories are restored for every grid. The saturated +0.02 cm case has an independent exact solution h=0.02, theta=theta_sat, qtop=qbot=-4.75 cm/day.

The runner retains hard soil mass 1e-10 cm and surface closure 1e-12 cm checks. The analyzer additionally checks interval ledger closure and analytical steady-flow transfer. Partial grids are never accuracy references. Every numerical result and failure snapshot is identical between O0/O2, excluding CPU. Raw O0 data and failure snapshots are persisted; O2 identity and per-log SHA256 are recorded in the result and reproducible analyzer. CPU timing is descriptive only.

## Baseline findings

All 180 saturated steady controls pass analytically, independently of geometry and lower-boundary mode. Thus imposed top head alone does not prevent a valid saturated solve.

All baseline mode 2 and mode 5 grids complete. Baseline mode 7 has 46 incomplete grids: 17 in original shallow geometry, 21 in consistent shallow geometry and 8 in the deeper column. Therefore correcting geometry alone does not remove the failure. These are 80-iteration nonlinear retries, not positive-qtop/exfiltration admission failures.

The deeper dry mode-7 case completes all 1..512 grids over six hours. At 512 steps its transfer is -2.3280809731 cm; the 256/512 profile L1 difference is 0.0090842363 cm. The deeper initially wet mode-7 case fails on several grids, while fixed flux/head alternatives complete. Lower-boundary interactions are therefore material, but the transient failures cannot be labelled a general inundation or Richards impossibility.

## Causal probes and falsification

Source inspection shows candidate-dependent free-drainage qbot=-K(h_N), while the SwKimpl=0 bottom diagonal lacks its dK/dh_N term. The external arithmetic-mean top face likewise varies with candidate head, while its existing head-boundary diagonal does not include the conductivity derivative. This is not itself proof that the accepted lagged-conductivity policy is defective.

A build-time generator made isolated HeadCalc copies. The first probe added only a central-difference bottom derivative, with scale 1e-5 or 1e-6 cm. Residuals, physical parameters, tolerances, iteration limit and all production files remained unchanged. The second added both bottom and imposed-head top conductivity derivatives. Finite differences are an investigative perturbation, not a qualified derivative service.

| Research variant | Incomplete grids / 540, per optimization | New incomplete mode 2/5 grids |
| --- | --- | --- |
| Stock | 46 | 0 |
| Bottom derivative, 1e-5 | 31 | 0 |
| Bottom derivative, 1e-6 | 31 | 0 |
| Both derivatives, 1e-5 | 34 | 3 |
| Both derivatives, 1e-6 | 33 | 2 |

The bottom-only probe preserves all fixed flux/head numerical records exactly but does not remove free-drainage failure. The combined finite-difference correction introduces failures in previously completed cases and has some perturbation-scale sensitivity. Both are falsified as sufficient production repairs. This does not falsify every analytically consistent Jacobian or continuation method. Near h=0, branch switching and constitutive regularity must be examined before selecting a derivative strategy.

## Consequence for the TOP03 route

Do not change a lower boundary to obtain a green fixture and do not admit either finite-difference probe. Do not choose production temporal tolerance from partial mode-7 runs. There are now complete deeper-column reference sequences for the dry free-drainage case and for physically specified pressure/flux lower boundaries. Use these to separate temporal transfer accuracy from the near-saturated free-drainage nonlinear problem.

The intended MODFLOW/head/flux lower-boundary application should be researched with its actual admitted boundary contract. That can advance TOP03 accuracy research without requiring a general free-drainage solution first. Any future production envelope must explicitly state the qualified lower-boundary modes. The near-saturated mode-7 route remains a separate numerical qualification requirement and cannot inherit mode-2/5 evidence.

Before a shared solver repair: capture iteration-level head, theta/capacity, top/bottom flux, frozen internal conductivities, candidate tuple provenance and line-search reduction on the same failed origin. Distinguish Jacobian inconsistency, saturated constitutive switching and the accepted frozen-K numerical problem. Obtain a complete same-equation refinement sequence before choosing a production acceptance criterion. No numerical policy or mass gate is waived.

## Reproduction

    bash tests/fapp/run_sw_rib_top03_boundary_diagnosis.sh tests/fsi/fsi04_real_headcalc_stubs.f90 1
    bash tests/fapp/run_sw_rib_top03_boundary_diagnosis.sh tests/fapp/top03_consistent_shallow_stubs.f90 2
    bash tests/fapp/run_sw_rib_top03_boundary_diagnosis.sh tests/fapp/top03_deep_column_stubs.f90 3

Append 1e-5 or 1e-6 for bottom-only research; append both after that value for the combined research. Save each output as top03-diag-gN.log, top03-probe5-gN.log, top03-probe6-gN.log, top03-both5-gN.log or top03-both6-gN.log respectively, then invoke analyze_sw_rib_top03_boundary_diagnosis.py LOG_DIRECTORY OUTPUT_DIRECTORY. Set the GNU Fortran path as needed. Exact source postimages are in TOP03_BOUNDARY_DIAGNOSIS_RESULT.json.
