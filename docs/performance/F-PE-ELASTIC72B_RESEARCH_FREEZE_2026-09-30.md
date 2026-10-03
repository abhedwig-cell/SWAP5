# F-PE-ELASTIC72B — research freeze and handoff

Date: 2026-09-30

Status: FROZEN_NOT_ACTIVE

Branch:
`research/f-pe-elastic72b-nobv-identifiability`

Freeze point:
`06a7ceca5d01754b8b3ed4e648754354d3512b8e`

## Decision

The peat / high-organic ELAS line is intentionally frozen.

No further NOBV data acquisition, model fitting, production shaping, solver
experiments or GitHub Actions are authorized by this work unit while the freeze
remains in force.

## Reason

The current evidence supports that reversible poroelastic deformation in peat
exists and is in principle identifiable from high-frequency extensometer and
groundwater observations.

However, for current SWAP5 priorities the expected practical value of refining
peat-specific ELAS is uncertain relative to larger unresolved uncertainties in:

- ordinary water-storage representation in peat/high-organic soils;
- waterlogging and near-surface saturation behavior;
- shrink/swell, consolidation, creep and irreversible subsidence;
- parameter uncertainty and heterogeneity in peat profiles.

Therefore the marginal value of a dedicated peat ELAS campaign is currently
judged insufficient to justify further research effort.

This is a prioritization decision, not a scientific statement that elastic
storage is absent or irrelevant in peat.

## Preserved conclusions

### Mineral soils

The mineral ELAS line is closed and remains the active physical conclusion:

- ELAS is treated as a physical skeleton/storage parameter;
- one universal `Ss = 1e-6 cm^-1` is not the preferred generated
  parameterization;
- the qualified BOFEK/BRO mineral prior is soil-dependent;
- the median generated mineral value is approximately
  `2.84e-6 cm^-1`;
- generated mineral ELAS remains separate from timestep and solver policy;
- explicit/user ELAS retains higher ownership.

### Peat and high-organic soils

Preserved evidence:

- BHR-GT same-interval peat-labelled settlement evidence was insufficient for a
  direct peat-specific calibration route;
- five high-organic non-peat settlement intervals were retained as descriptive
  evidence only;
- the NOBV/Deltares extensometer route is physically promising;
- for a saturated anchor-bounded layer under quasi-static head variation,
  `Ss_skeleton ~= -d(epsilon_z)/dH`;
- offline synthetic and measurement-design work showed that coefficients in the
  existing ELAS magnitude range are in principle detectable with realistic
  high-frequency monitoring geometry;
- raw NOBV multi-anchor and groundwater data would still be required for an
  actual peat estimate.

No peat/high-organic automatic ELAS assignment is qualified.

## Production status

Unchanged:

- MINERAL generated ELAS: qualified within its admitted scope;
- PEAT: RESEARCH_ONLY_NOT_AUTO_ASSIGNED;
- ORGANIC_RICH_NONPEAT: RESEARCH_ONLY_NOT_AUTO_ASSIGNED;
- explicit/user ELAS remains possible;
- no peat-specific default is introduced;
- no solver or timestep policy changes follow from this freeze.

## Reopen criteria

Do not reopen this line merely because more time or runner capacity becomes
available.

A justified reopening requires at least one of:

1. a SWAP5 application demonstrates material sensitivity of relevant outcomes
   to peat ELAS beyond the uncertainty from ordinary storage/waterlogging
   parameterization;
2. NOBV/Deltares multi-anchor raw data become readily available and can answer
   the question at low additional research cost;
3. a coupling or inundation application reveals a clear mass/storage error that
   cannot be explained without a peat elastic-storage term;
4. new independent evidence indicates that peat reversible storage is large
   enough to affect decisions at the model scale of interest.

If reopened, resume from:
- `F-PE-ELASTIC72A_PEAT_SOURCE_RESULT.md`;
- `F-PE-ELASTIC72B_NOBV_IDENTIFIABILITY_PREREGISTRATION.md`;
- `F-PE-ELASTIC72B_LOCAL_PREFLIGHT_RESULT.md`;
- `F-PE-ELASTIC72B_MEASUREMENT_DESIGN_RESULT.md`;
- `F-PE-ELASTIC72B_PUBLIC_ACCESS_RECONNAISSANCE.md`;
- `F-PE-ELASTIC72B_DATA_REQUEST_TEXT.md`.

## Closure classification

`PEAT_ELAS_LINE_FROZEN_LOW_CURRENT_PRIORITY`.

The work is preserved and recoverable. No active blocker remains because no
further action is currently required.
