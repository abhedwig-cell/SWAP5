# PPA-WU05B2: explicit empirical root frost composition

Status: implemented candidate, not canonically admitted. Original baseline is
`53a3f3e41231b8600bbb19b8eb2157558bd12e19`.

The legacy macro-root rule sets uptake to zero below 0 C. Exactly 0 C
remains eligible. This plant rule is distinct from the continuous empirical
hydraulic conductivity reduction; their differing shapes do not alone establish
an incompatibility. The earlier blanket rejection of root frost was too strong.
This migration names the source compatibility rule explicitly and does not infer
plant response from the hydraulic frost factor.

The pure root composer applies the cutoff to committed trial-start temperature.
Drought, wetness and frost losses use source-weighted node attribution. Jarvis
selectors ALL, DROUGHT, OXYGEN and FROST use those exponent shares; Walsum supplies
the existing geometry-derived alpha. Uniform compensation preserves zero uptake
in frozen and unrooted nodes. A single final sink enters Richards and the existing
water ledger and accepted actual-transpiration publication. No committed state,
restart schema, ice inventory or latent heat owner is added.

The opt-in route requires Reference, sensible soil temperature, hydraulic frost,
root extraction, zero prescribed qbot and explicit positive temporal budgets.
Bartholomeus plus negative-temperature frost remains outside this candidate.
FrozenBounds, drainage mutations and nonzero frozen bottom flux remain excluded.
This is empirical source compatibility, not independent physiological validation.

## Temporal acceptance and observed limitation

The incumbent full/half identity test rejects nonzero root uptake even when
Richards converges and water mass closes. The new root-frost route alone compares
pressure heads, ponding and groundwater in cm and temperature in C using separate
supplied positive budgets and a dimensionless maximum. Invalid states, missing
budgets or different final frozen-root classifications are unavailable and refine.
Existing OFF and rootless frost temporal policies remain unchanged.

Qualification uses local full/half budgets of 1e-6 cm and 1e-6 C with dimensionless
acceptance 1. Comparing a 1e-4 day mixed-temperature run with 2,048 direct smaller
steps gives head difference 1.511038e-7 cm and temperature difference
7.351853e-5 C. The temperature difference fails a cumulative 1e-6 C assertion.
That failed assertion is retained as a limitation: a local step budget does not
establish that cumulative bound. The explicit horizon comparison bounds are
1e-6 cm and 1e-4 C. This must be assessed in admission rather than described as
global 1e-6 C accuracy.

## Reproducible qualification

- `bash tests/frost/run_ppa_wu05b2_root_frost.sh`: cutoff, invalid input,
  three-stressor attribution, all four selectors, no frozen-root resurrection,
  alpha-one preservation and Walsum geometry at O0/O2.
- `bash tests/frost/run_ppa_wu05b2_root_frost_runtime.sh`: actual Reference trials,
  refinement and direct continuation, accepted publication, actual thaw,
  committed restart into a fresh worker, public Jarvis/Walsum applications and
  unsupported boundary/missing-budget rejection at O0/O2.
- Existing hydraulic frost runtime, Jarvis and Walsum application qualifications
  remain preservation obligations, followed by full current-canonical preservation.

Source hashes are recorded in `integration/audits/PPA_WU05B2_SOURCE_MANIFEST.json`.
The status file is authoritative for completion and admission. The aggregate frost
migration remains incomplete until all separately bounded work units are admitted.

## Current-canonical reconciliation

Canonical advanced to `916035e78305cae5f88c30d5805b5d9c33a348f8` with the
admitted matrix-salinity owner. The root compensation API keeps its existing
positional salinity arguments and appends named frost arguments. Both selectors
4 and 5 remain distinct. Salt and frost diagnostic owners coexist, while joint
nonzero salt/frost stress is unsupported pending separate qualification. Public
application admission also excludes simultaneous root-salinity or salt state.
Active matrix-salt and dispersion runtime preservation is repeated on the merged
source; the pre-reconciliation full moving-canonical pass is not current admission.
