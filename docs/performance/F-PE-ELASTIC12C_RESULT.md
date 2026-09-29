# F-PE-ELASTIC12C — low-stress R3 mechanical target result

Date: 2026-09-29

Status: LOW_STRESS_TARGET_SET_QUALIFIED

Qualified workflow:
`F-PE-ELASTIC12C low-stress target extraction`

Run:
`36539242031`

Job:
`109310428223`

Qualified head:
`38720d4f913621ec9a5fdc40bdaf9b398151f221`

Artifact:
`f-pe-elastic12c-low-stress-targets`

Artifact id:
`11019543072`

Artifact digest:
`sha256:887e87b13bf0ee4e890567fa715fce1bf233ff0a8ec303bc51a4cc74bcdce864`

## Frozen source

Targets were derived only from the frozen F-PE-ELASTIC12B artifact:

- source run: `36538267535`;
- source artifact id: `11018544503`;
- source artifact digest:
  `sha256:c47ebb65c641a4b01504e709f4b65da27816aba4d99e72f15c5b1f3dcc3e3f7b`.

No BHR-GT object was refetched.

All five object SHA-256 and byte-size checks passed.

## Frozen estimator

For each exact R3 unload candidate:

1. select finite rows with
   `0 < verticalEffectiveStress <= 25 kPa`;
2. preserve source series order;
3. take the first and last selected rows;
4. convert strain percent to fraction and kPa to Pa;
5. calculate:

`mv = abs(delta_epsilon / delta_sigma')`

and:

`Ssk = gamma_w * mv`

with:

`gamma_w = 9806.65 N/m3`.

No candidate, threshold or estimator was changed after target magnitudes were
seen.

## Target results

| BRO ID | Stress secant (kPa) | Strain secant (%) | Ssk (cm^-1) | OLS R2 diagnostic |
|---|---:|---:|---:|---:|
| BHR000000466495 | 25.00 -> 22.51 | 2.43 -> 2.39 | 1.5754e-5 | 0.9443 |
| BHR000000466498 | 24.97 -> 22.96 | 2.41 -> 2.34 | 3.4153e-5 | 0.9771 |
| BHR000000469044 | 24.72 -> 18.76 | 2.97 -> 2.86 | 1.8100e-5 | 0.9721 |
| BHR000000469048 | 24.90 -> 23.85 | 2.35 -> 2.32 | 2.8019e-5 | 0.6350 |
| BHR000000469193 | 24.92 -> 19.79 | 20.21 -> 19.74 | 8.9847e-5 | 0.9913 |

All five targets are finite and positive.

Markers:

- `F_PE_ELASTIC12C_VALID_TARGETS=5/5`;
- `F_PE_ELASTIC12C_FAILURES=0`;
- `F_PE_ELASTIC12C_CLASSIFICATION=LOW_STRESS_TARGET_SET_QUALIFIED`;
- `F_PE_ELASTIC12C=PASS`.

## Population range

Low-stress target Ssk in `cm^-1`:

- minimum: `1.5754e-5`;
- median: `2.8019e-5`;
- maximum: `8.9847e-5`.

These values are substantially larger than Pim Dik's proposed
`1e-6 cm^-1`.

That comparison is descriptive only. The five BHR-GT targets are specimen-scale
low-stress mechanical targets and are not yet root-zone production parameters.

## Linearity diagnostic

The optional OLS diagnostic was not used for target selection.

Four objects have OLS `R2 >= 0.94` over the <=25 kPa unload subset.

BHR000000469048 has lower OLS `R2 ~= 0.635`.

Per preregistration this candidate is retained. No post-result filtering is
allowed.

The discrepancy is useful diagnostic evidence for the successor falsification
step and must not be hidden by replacing the frozen endpoint estimator.

## Interpretation

F-PE-ELASTIC12A established that direct use of the qualified deep M5 relation in
the saturated root-zone regime was an extrapolation.

F-PE-ELASTIC12B established that direct low-stress unload evidence exists.

F-PE-ELASTIC12C now establishes a complete five-object low-stress mechanical
target set independent of M5 fitting.

This closes the low-stress data-gap blocker.

## Decision

Classification:

`LOW_STRESS_TARGET_SET_QUALIFIED`.

A separate successor may now evaluate the already frozen deep M5 relation
against these targets.

No M5 coefficient may be refitted, no low-stress target may be dropped, and no
SWAP performance result may enter that evaluation.

## Scientific boundary

Not qualified here:

- root-zone ELAS generation;
- BOFEK/Staringreeks ELAS values;
- a universal `1e-6 cm^-1` default;
- stress-independent storage;
- use of BHR-GT specimen Ssk as a direct field-scale SWAP parameter.
