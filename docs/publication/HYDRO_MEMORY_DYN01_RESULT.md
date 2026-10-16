# HYDRO-MEMORY DYN01 result

**Decision:** `DYN01_PASS_FORCING_AND_ACCEPTED_STATE_DEPENDENT_FEDDES_COMPOSITION`

DYN01 closes the standalone composition prerequisite between the admitted atmospheric-forcing route and the admitted restricted Feddes root-uptake route.

Qualification:

- source head: `4d5a9a403cc9ac63ada2fe9e11e1fc42296e741d`
- workflow: **35459983635**
- job: **105941988359**
- production/reference delta: none

The frozen full-cover canopy causes reference ET to map directly to potential transpiration:

- drought: 4 mm d-1 -> 0.4 cm d-1;
- recovery: 3 mm d-1 -> 0.3 cm d-1.

At the wet reference state the admitted dynamic-top route gives:

- drought precipitation 0 -> top flux 0 cm d-1;
- recovery precipitation 0.5 cm d-1 -> top flux -0.5 cm d-1.

The restricted F-CI31 Feddes composition is demonstrably state dependent while remaining stateless with respect to evaluation:

- wet drought actual uptake: 0.400000 cm d-1;
- dry-state drought actual uptake: 0.394710 cm d-1;
- wet recovery actual uptake: 0.300000 cm d-1.

The dry state was frozen before execution with the first three rooted-node pressure heads at -1200, -800 and -400 cm. Repeated evaluation from the same committed state is bit-stable, and neither forcing materialization nor root-uptake evaluation mutates the committed revision.

O0/O2 output identity passes.

## Scope

The F-VQ46 root geometry and Feddes parameter set are authority for this composition qualification only. They are not yet the final scientific Stage-0 crop/root parameterization. DYN01 does not yet exercise live MODFLOW coupling and does not authorize the 90-day experiment.

The next gate is DYN02: recompute atmospheric forcing and the immutable-in-window Feddes sink from each accepted committed state, then execute the existing live root-active coupling lifecycle without changing the ACC01/ACC02 numerical accuracy policy.
