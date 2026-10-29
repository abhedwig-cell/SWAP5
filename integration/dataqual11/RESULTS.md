# DATAQUAL11: original projects and duration-forcing implementation

Baseline: `61f723911c1936fd1860947053857eb7b7b9a84b` (DATAQUAL10 receipt).

The intended increase in independently executing **integral model projects was
not achieved**. Three complete original projects are now byte-exact and locally
replayable from the official distribution, plus one non-runnable salinity template.
The distribution SHA-256 and every original case member are in
`reference/swap-4.3.1/projects/MANIFEST.json`. New forcing work must not be counted
as successful soil/crop/heat/solute model integration.

- Hupselbrook: original 34 nodes, 1096 days, direct PM, mixed simple/dynamic crops,
  DRAMET2, free drainage, heat and solute. Actual driver rejects SWETR0 before steps.
- Grassgrowth: original 113 nodes, 1827 days, dynamic grass, direct PM, SWRAIN2,
  DRAMET3 and prescribed groundwater. Actual driver rejects SWETR0 before steps.
- Macroporeflow: original 112-node Andelst, 481 days. Five-day attempt censored at
  30 seconds; last complete daily budget at day1, later accepted progress1.076.
  Retained restart is evidence of a censored original calculation, not a new
  qualified result or a second independent historical project.
- Salinitystress: unresolved generation-template fields. TTUTIL rejects the
  unchanged template; no generated physical input is fabricated.

## Implemented and executed

New pure `mod_daily_rain_duration` and original-input adapter implement SWRAIN2
rain depth/duration conversion, preserving source thresholds and finite guards.
All1827 original Grassgrowth weather records execute on checked O0 and O2:
951 wet days,2778 events,410.11cm rain. Duration and rate match executable literal
B0 arithmetic on every original record. O0/O2 event files are byte-identical.
Maximum independently integrated daily event-depth error is2.585e-12cm.
Dry/threshold and inconsistent/negative/out-of-domain/nonfinite cases pass.
This is **forcing-only** scope: the new adapter is not wired into the rejected
whole-project route. No replacement ET, simplified grass, altered boundary or
synthetic physical parameters are used. No kernel accepted state is touched.

A native TTUTIL inspection adapter exposes original selectors without weakening
execution guards. Its output is exact O0/O2 on the three complete projects.
`tools/solute/run_historical_projects.py` verifies original input hashes and runs
independent bounded model processes; it preserves rejected preparation separately
from actual model execution and from forcing-only results.

## Comparison with DATAQUAL10

151 variants,83 water-qualified variants,94.748 configuration-days and the
2.748-day original integral maximum remain inherited and unchanged. These are
**decimal days**, not94748 and2748 days. Zero new integral projects, zero new
full-project qualifications, zero new full executable431 comparisons. The new
rainfall comparison is to the literal original forcing arithmetic, not the
complete SWAP431 executable. Model water/solute restart and energy qualification
are not established by the forcing checks.

`MIGRATION_MATRIX.json` is the compact project-by-function status authority for
this work:3 complete originals;0/3 full migrations;1/3 with inherited bounded
water evidence. Features without an original integrated execution stay blocked
or implemented-but-not-executed, irrespective of standalone module maturity.

## Remaining integration blocks

1. File-led direct PM coupling for Hupsel and Grassgrowth, using the existing
   admitted PM process and typed bindings.
2. Dynamic WOFOST potato/grass ownership and application composition.
3. Original boundary1/6 and Hupsel DRAMET2 application coupling.
4. No-macropore water/heat and water/solute application composition with these
   original ET/crop/boundary combinations.
5. Complete generated Salinitystress inputs are absent; do not count its template
   as an executable independent project.

No old solver/provider, accepted physical law, tolerance, numerical policy,
rollback or restart layout changes. Existing component evidence is not rerun or
relabeled as new evidence. No full F-CI or full431-equivalence claim.

Reproduce new source qualification:

```sh
python tests/dataqual11/qualify_original_rain.py --distribution /path/SWAP_4.3.1.zip --ttutil /path/native-O0/shared/libttutil.a --output /path/new-rain-evidence --fc /path/gfortran
python tools/solute/run_historical_projects.py --bundle /path/native-O0 --output /path/new-project-batch --days 5 --timeout-seconds 30
```

Raw attempts, partial budgets/restart, compiler/source build provenance, source
oracle and native outputs are retained in `EVIDENCE.tar.xz`; identities and
proportional selection are in `STATUS.json` and `RAIN_QUALIFICATION.json`.
