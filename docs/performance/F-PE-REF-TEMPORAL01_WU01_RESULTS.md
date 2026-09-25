# F-PE-REF-TEMPORAL01 WU01 — indicator versus refined Reference

Date: 2026-09-25

Status: `WU01_PASS_INITIAL_CONSERVATIVITY`

Source head: `2eb43477ddfe48cccc19075e4018eeba80874c6f`

Workflow run: `36119117284`

## Scope

Initial deterministic calibration matrix for the existing Reference temporal indicator against an independently refined Reference trajectory.

No production temporal budget was selected in this work unit.

## Matrix

12 cases:

- initial pressure head: -75, -250, -1200 cm;
- flux factor: -0.01 and +0.01 relative to local conductivity;
- principal dt: 1e-2 and 1e-3 day;
- bottom mode: prescribed qbot (mode 2);
- refined oracle: 16 equal Reference substeps;
- no roots, macropores, snow, drainage response, soil temperature or evaporation-memory process.

O0 and O2 outputs were semantically identical.

## Result

All 12 cases were classified:

`BOUND_VALID_CONSERVATIVE`

Counts:

- conservative: 12;
- nonconservative: 0.

Observed bound / refined-endpoint head-error ratios ranged from:

- minimum: 2.22819986;
- maximum: 312.913266.

The minimum occurred for the wetter, larger-dt cases around h=-75 cm.

Representative rows:

| h0 cm | q factor | dt day | indicator bound cm | refined head error cm | bound/error |
| ---: | ---: | ---: | ---: | ---: | ---: |
| -75 | -0.01 | 1e-2 | 0.625180266 | 0.280331520 | 2.230 |
| -75 | +0.01 | 1e-2 | 0.637834658 | 0.286255586 | 2.228 |
| -250 | -0.01 | 1e-2 | 0.243875312 | 0.0431851693 | 5.647 |
| -250 | +0.01 | 1e-3 | 0.0313634943 | 0.00110846997 | 28.294 |
| -1200 | -0.01 | 1e-2 | 0.0247944541 | 0.000722025949 | 34.340 |
| -1200 | +0.01 | 1e-3 | 0.00260459676 | 0.00000832370324 | 312.913 |

Water-content endpoint errors were small and storage differences were at floating-point noise level for this balanced-flux matrix.

## Interpretation

This is encouraging evidence that the existing temporal indicator is conservative on the initial calibration domain.

It is not sufficient for production admission.

The matrix is still narrow:

- one hydraulic parameter set;
- uniform initial profiles;
- balanced top/bottom flux;
- only two dt values;
- no state gradients;
- no difficult near-saturation transition;
- no dry-end constitutive edge;
- no groundwater-head mode;
- no heterogeneous layers.

The very large safety factors in dry/small-dt cases also show that conservativeness alone is not enough. A production budget must not be so conservative that it destroys performance.

## Decision

Do not choose a production temporal budget yet.

Proceed to WU02:

`expanded conservativity and sharpness matrix`

with emphasis on cases likely to reduce the safety margin:

1. wet and near-saturated states;
2. nonuniform vertical head profiles;
3. stronger forcing;
4. larger dt;
5. multiple hydraulic parameter sets/materials;
6. upward/downward flux asymmetry;
7. prescribed-head groundwater boundary where already indicator-qualified.

The same refined Reference oracle remains authoritative.
