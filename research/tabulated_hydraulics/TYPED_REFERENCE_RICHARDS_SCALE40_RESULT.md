# TAB-HYD typed Reference Richards 40-node scale result

Date: 2026-09-23

Status: **SCALE_PASS — supplemental qualified research evidence**

## Question

Does the generated raw-head400 K0 constitutive provider retain scientific
fidelity and its local Reference-Richards runtime advantage when the bounded
typed solver fixture is enlarged from 4 to 40 vertical nodes?

This is a supplemental research scale gate. It does not establish a portable
whole-SWAP speedup and does not replace production F-TAB02 qualification.

## Authority

Preregistration:

`research/tabulated_hydraulics/TYPED_REFERENCE_RICHARDS_SCALE40_PREREGISTRATION.md`

Canonical solver/source authority pinned by the workflow:

`integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`

Controlling run:

- run `35883123788`
- research commit `a25086fa47966e2c8f26fc93da726f26905488aa`
- conclusion: PASS

Independent execution-equivalent repeat:

- run `35883189377`
- research commit `7996dafaed03f933cd7192ffafe90a2ee61893db`
- conclusion: PASS

The second commit differs only by binding the workflow trigger to the
preregistration file; the scientific fixture and executable source are
execution-equivalent.

Earlier scale40 failures are superseded technical harness failures. They did not
reach a valid model comparison.

## Fixture

Five existing TAB-HYD profiles were expanded to 40 nodes:

- coarse_dry_free;
- loam_mid_free;
- clay_wet_free;
- coarse_dry_pulse;
- loam_capillary.

The scale fixture changes node count while retaining the same bounded
constitutive/provider comparison logic. Analytical and generated routes use:

- identical pressure-head initial conditions;
- provider-consistent initial water content;
- the same current-canonical Reference Richards solver;
- the same numerical configuration;
- the same forcing and boundary conditions;
- K0 / `SWKIMPL=0`.

No solver tolerance or representation parameter was tuned after observing the
result.

## Scientific result

All five scenarios satisfy every preregistered gate.

| scenario | max |Δh| (cm) | h RMSE (cm) | max |Δtheta| | |Δmass| (cm) | nonlinear iters A/T |
| --- | ---: | ---: | ---: | ---: | ---: |
| coarse_dry_free | 1.38157e-5 | 2.66195e-6 | 4.12254e-9 | 7.99e-16 | 4 / 4 |
| loam_mid_free | 8.27741e-7 | 1.41073e-7 | 5.27011e-10 | 2.22e-15 | 4 / 4 |
| clay_wet_free | 9.14082e-7 | 1.46169e-7 | 4.04465e-10 | 5.55e-16 | 4 / 4 |
| coarse_dry_pulse | 1.38157e-5 | 2.54762e-6 | 4.04580e-9 | 3.47e-16 | 4 / 4 |
| loam_capillary | 3.24192e-7 | 5.19608e-8 | 8.42857e-10 | 1.87e-15 | 3 / 3 |

Acceptance limits were:

- max |Δh| <= 5e-2 cm;
- h RMSE <= 1e-2 cm;
- max |Δtheta| <= 2e-2;
- absolute mass residual on each route <= 1e-8 cm;
- identical nonlinear iteration counts.

The observed differences are orders of magnitude inside the declared limits.

## Performance characterization

### Controlling run 35883123788

| scenario | analytical median (s) | table median (s) | table delta |
| --- | ---: | ---: | ---: |
| coarse_dry_free | 0.0028715 | 0.0019345 | -32.63% |
| loam_mid_free | 0.0028700 | 0.0019305 | -32.74% |
| clay_wet_free | 0.0028920 | 0.0020230 | -30.05% |
| coarse_dry_pulse | 0.0029135 | 0.0019995 | -31.37% |
| loam_capillary | 0.0022610 | 0.0015125 | -33.10% |

### Independent repeat 35883189377

| scenario | analytical median (s) | table median (s) | table delta |
| --- | ---: | ---: | ---: |
| coarse_dry_free | 0.0017790 | 0.0011230 | -36.87% |
| loam_mid_free | 0.0018150 | 0.0011530 | -36.47% |
| clay_wet_free | 0.0018050 | 0.0011970 | -33.68% |
| coarse_dry_pulse | 0.0018320 | 0.0011540 | -37.01% |
| loam_capillary | 0.0014170 | 0.0008645 | -38.99% |

Absolute wall times differ between runner executions, so the exact percentages
must not be treated as portable constants. What reproduces is the qualitative
and material result: the generated provider is faster in every tested 40-node
profile while the solver trajectory class remains unchanged.

## Interpretation

The 4-node Reference-Richards acceleration does not disappear when the bounded
fixture is increased to 40 nodes.

The correct research conclusion is therefore:

> Within the tested current-canonical typed K0 Reference-Richards fixtures, the
> generated raw-head400 provider preserves the bounded solution and retains a
> material runtime advantage at 40 nodes.

This strengthens the production handoff by removing the concern that the
earlier 4-node result was only an artifact of an extremely small,
constitutive-dominated column.

It still does **not** establish:

- a 30–39% whole-SWAP speedup;
- a portable percentage across hardware/compilers;
- a MultiSWAP speedup;
- whole-Hupsel speedup;
- SWKIMPL=1 performance;
- generic user-table performance.

Production F-TAB02 evidence remains the authority for production implementation
and eventual admission.

## Disposition

**SCALE_PASS / K0 RESEARCH SCALE QUESTION CLOSED**

No further representation tuning is justified by this gate.

The research line should remain closed unless a new production qualification
result exposes a concrete dependency or scientific discrepancy that falls back
inside TAB-HYD research ownership.
