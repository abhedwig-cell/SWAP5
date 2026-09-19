# F-ROMV2 D3 representation-policy adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D3  
**Decision:** **REPRESENTATION_AWARE_PROSPECTIVE_POLICY_NO_GO**

## Purpose

D3 tested whether deliberately coarse Richards models could be evaluated under a
research-only local balance policy derived prospectively from floating-point
representation scale rather than from the historical fixed Reference
`1e-12 cm/day` compartment-rate criterion.

The policy was frozen before execution and did not use D2 residual magnitudes.

## Execution

Workflow run **35444680718**, job **105901462241**, executed head
`53713dcb3ccafc78ee0e4ae771e17d0b2555f885`.

Artifact:

- ID: **10584293128**
- digest: `sha256:71350b5e2066f5cf8cf1efc7ac191c998648483b7224ae484efc0ba2181d3c44`

The workflow conclusion is failure because its post-census runner still
required R16 to be COMPLETE. Before that assertion, all four preregistered
geometries had already been executed at O0 and O2 and classified under the
frozen policy. The failure is therefore the terminal negative D3 result, not a
missing experiment.

## Frozen policy

The first attempt retained the strict Reference controls.

For a pure `RETRY_LOCAL_BALANCE` failure with zero head flags and immutable
committed state, D3 computed before the reattempt:

[
b_i =
\tfrac{1}{2}
\left[\operatorname{spacing}(\theta_s)
     +\operatorname{spacing}(\theta_{i,base})\right]
\Delta z_i .
]

The allowed local integrated residual was the maximum (b_i); the total
representation bound was the sum of all (b_i). A qualifying reattempt could
not relax the separate hard accepted-transaction mass gate of (10^{-12}) cm.

This was deliberately more conservative than fitting a threshold to D2.

## Result

Every geometry eventually violates the prospective local bound.

| geometry | local residual | prospective local bound | total residual | head flags |
|---|---:|---:|---:|---:|
| R16 | 8.257e-16 cm | 5.551e-16 cm | 2.435e-15 cm | 0 |
| R8 | 1.230e-15 cm | 1.110e-15 cm | 1.605e-15 cm | 0 |
| R4 | 2.779e-15 cm | 2.220e-15 cm | 6.150e-16 cm | 0 |
| R2 | 4.625e-15 cm | 4.441e-15 cm | 2.836e-15 cm | 0 |

The terminal failures are all `RETRY_LOCAL_BALANCE`, not head failures.

The total integrated residuals are roughly three orders of magnitude below the
independent hard accepted-transaction water-depth gate of (10^{-12}) cm.

## Scientific interpretation

D3 falsifies the proposed **prospective representation-bound policy** as a
general numerical authority for reduced hydrological models.

The strongest evidence for that conclusion is R16 itself. A policy intended to
make deliberately coarse reductions measurable is not useful if it rejects the
fuller-grid development reference on the same exposed workload.

D3 does **not** establish that R16, R8, R4 or R2 are hydrologically invalid.

It also does not overturn D2's measured R8 hydrological discrepancies. D2 and
D3 answer different questions:

- D2 measured R8 fidelity under a previously available strict-first route;
- D3 tested a candidate numerical-admissibility rule and found that rule too
  restrictive.

## Why D3 is not retuned

The observed ratios between local residual and prospective representation bound
are now exposed. Multiplying the bound by an empirical factor after seeing
those ratios would convert a preregistered numerical hypothesis into post-hoc
calibration.

That is prohibited.

Any successor must be independently justified from authority that existed
before D3.

## Next numerical-integrity hypothesis

A defensible successor is an **integrated water-depth residual policy** tied
directly to the already established hard transaction mass scale rather than to
a fixed rate or a prospective ulp estimate.

For a step of duration (Delta t), a research-only local/total rate tolerance

[
\varepsilon_{rate} = \varepsilon_{depth}/\Delta t
]

with independently fixed
(arepsilon_{depth}=10^{-12}) cm keeps the allowed residual water depth per
accepted interval constant.

This avoids the artificial (1/\Delta t) tightening of a fixed rate threshold
while remaining orders of magnitude stricter than the hydrological
discrepancies under study.

That successor is **not authorized by D3 itself**. It requires a separate
preregistration before execution.

## Boundary

D3:

- changes no production or Reference source;
- changes no production Reference tolerance;
- supplies no application acceptance;
- supplies no performance claim;
- supplies no production ROM authority.

Production ROM remains unauthorized.
