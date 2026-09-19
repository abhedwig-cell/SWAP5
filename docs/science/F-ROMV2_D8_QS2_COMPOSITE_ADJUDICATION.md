# F-ROMV2 D8 QS2 composite-manifold adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D8  
**Decision:** **QS2_COMPOSITE_NOT_COMPETITIVE_OR_NOT_ROBUST_IN_EXPOSED_B01_DOMAIN**

## Question

D8 tests whether the missing dynamic profile memory diagnosed in D7 can be recovered by conserving two independent 80-cm storage states while retaining quasi-steady profile reconstruction inside each segment.

This is deliberately different from both predecessors:

- D5 used two dynamic layer averages but closed fluxes from instantaneous Darcy gradients between average states;
- D7 used a physically resolved quasi-steady profile but only one dynamic total-storage state;
- D8 combines two independent dynamic balances with non-local steady-profile reconstruction inside both segments.

The lower segment is solved first from lower-zone storage and the lower boundary. Its reconstructed top pressure head becomes the exact bottom pressure head of the upper segment. The upper segment then solves its own interface flux from upper-zone storage.

Thus (q_{top}), (q_{int}), and (q_{bot}) may differ during an interval and the difference is stored dynamically in the two segment water balances.

## Immutable execution

Preflight run **35447903023** passed all 15 synthetic storage/boundary combinations.

Full workflow run **35448009892**, job **105910200873**, executed head
`efe098fcb2a51926fb92c37a60ebd52446a4d598`.

Artifact:

- ID: **10585551503**
- digest: `sha256:5b24db1d8fb089fa20bd4418d822856eb3cebdb4653930faacabe2912c77564d`
- preflight result SHA-256:
  `b26c7e8920b57e8c07994bbc2037e005ea85175ceb9bf8864efaab325a1e249e`
- hydrological result SHA-256:
  `6fb44f6f3db281f50210e51c09f19ea6953e8f23b61eb7018bd51e6e91e6cea3`
- R16 O0/O2 SHA-256:
  `e74c3e565c4c4f30c414102f09c6b24d746ea49e4e512d410aeb46641a4fc5fe`.

The R16 O0/O2 outputs are bitwise identical.

## Preflight

Five synthetic vertical-storage states were crossed with three lower-boundary conditions:

- equilibrium;
- upper dry / lower wet partition perturbation;
- upper wet / lower dry partition perturbation;
- both segments slightly dry;
- both segments slightly wet;

against:

- equilibrium prescribed bottom flux;
- raised prescribed bottom head;
- lowered prescribed bottom head.

All 15 combinations reconstruct finite physical lower and upper segment profiles.

The equilibrium control reproduces the expected interface and bottom flux branch.

The frozen preflight decision is:

`D8_QS2_COMPOSITE_PREFLIGHT_PASS`.

No search, segmentation or equation retuning is permitted after this point.

## Integrity

QS2_COMPOSITE completes all 12 exposed development histories.

There are:

- no nonfinite states;
- no clipping;
- no adaptive dynamic substeps;
- no trajectory training;
- no full-order fallback;
- no hidden mass correction.

Maximum absolute transaction mass residual is approximately

**3.31e-15 cm**,

well below the frozen **1e-12 cm** gate.

D8 is therefore not an integrity no-go.

## Hydrological fidelity

Relative to R16:

| metric | D5 L2_IMC | D7 QS1 | D8 QS2 | R2 |
|---|---:|---:|---:|---:|
| total-storage RMSE | 0.051645 cm | 0.047338 cm | **0.044070 cm** | **0.040709 cm** |
| cumulative bottom-exchange RMSE | 0.051645 cm | 0.047338 cm | **0.044070 cm** | **0.040709 cm** |
| terminal bottom-flux RMSE | 3.579 cm d-1 | 3.344 cm d-1 | **3.180 cm d-1** | **3.002 cm d-1** |
| bottom-flux sign errors | 136/768 | 136/768 | 136/768 | 136/768 |
| histories with reversal mismatch | 8/12 | 8/12 | 8/12 | 8/12 |

The sequence D5 → D7 → D8 shows monotonic improvement in balance and flux-magnitude fidelity.

However, D8 still does not cross the preregistered R2 frontier.

The balance view fails.

The transient view fails.

Therefore the frozen decision is:

`QS2_COMPOSITE_NOT_COMPETITIVE_OR_NOT_ROBUST_IN_EXPOSED_B01_DOMAIN`.

## Where D8 improves

The upper-zone result changes substantially.

Pooled upper 0-80 cm storage RMSE is only approximately

**0.00152 cm**.

That is far better than the one-state QS1 profile partition and shows that an independent upper-zone storage coordinate contains real transient memory.

This is strong evidence that the conceptual move from one dynamic balance to two dynamic balances is physically meaningful.

## Where D8 still fails

Pooled lower 80-160 cm storage RMSE remains approximately

**0.04264 cm**.

That term dominates the total-storage discrepancy and remains coupled to the groundwater-exchange error.

Examples from the exposed histories include:

- D03 cumulative-bottom-exchange RMSE about 0.0956 cm and final relative error about +362%;
- D06 bottom-flux RMSE about 5.06 cm d-1;
- V02 final cumulative-exchange error about +25.2%;
- V01-V04 all retain reversal-sequence mismatch.

These percentages are observations, not acceptance thresholds.

The physical diagnosis is therefore narrower than after D7:

> the upper-zone dynamic partition is largely recovered, while lower-zone storage and groundwater-exchange memory remain insufficient.

## Purpose-dependent meaning

### Long-term regional water balance

**Improved but not retained against R2.**

D8 moves in the intended direction and is closer to the regional-balance use case than D5 or QS1, but a simpler already available coarse-Richards comparator still has smaller development errors.

### Groundwater-coupled many-column simulation

**Not qualified.**

The remaining discrepancy is concentrated precisely in the lower-zone storage and groundwater exchange that drive a coupled groundwater response.

### Fast-event and threshold-sensitive simulation

**Not qualified.**

### Operational soil moisture and drought

**Not tested.**

### Scientific process/extreme inference

**Not qualified.**

## Scientific consequence

D8 should not be tuned by changing the 80/80 split, adding a third segment, increasing RK4 resolution or altering the root search after seeing these results.

The evidence does make additional lower-zone resolution scientifically plausible. MetaSWAP's published composite-profile concept also notes that more subsoil profile segments can improve accuracy.

But another custom segmentation should not be invented until the existing published two-layer integrated-Richards literature is reconciled.

He et al. published a genuinely different two-layer reduced Richards formulation based on vertically integrated conservation equations, with reported performance for layer-mean water contents, fluxes and dynamic shallow groundwater conditions.

Our D5 and D8 are **not** faithful reproductions of that model.

Therefore the next workunit should answer:

> Does the published integrated two-layer Richards formulation provide a stronger existing cost-fidelity candidate than the clean-sheet D5/D8 reductions?

Only after that literature-bound comparison is resolved is a custom three-segment or lag-state architecture justified.

R8, R4 and R2 remain the physical-reduction comparators.

Production ROM remains unauthorized.
