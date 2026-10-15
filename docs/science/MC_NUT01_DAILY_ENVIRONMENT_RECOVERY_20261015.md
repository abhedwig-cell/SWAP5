# Daily Soil-N environment recovery, 15 October 2026

Work unit MC-NUT01-DAILY-ENVIRONMENT; PR1236.
Baseline dca8cbd87ceff62406d0d1a38447b7a7bc8fbd1c, admitted crop supply1235.
State authority remains the existing reactive soil owner inside the existing
crop-soil state. No permanent temperature, inventory or new codec is introduced.

`soil_n_day_environment_t` is explicit input for one exact daily interval. The
optional forcing flows through the real Richards/crop/soil application and replaces
only the temperature used by both existing organic and mineral rate functions.
Reference temperature, saturation, parameters and stored identity stay unchanged.
Absent forcing retains original operation; stale/invalid forcing rejects the
entire attempt. Moisture still comes from accepted hydraulic endpoints.

This is prescribed scalar forcing. It does not derive soil temperature from air,
claim a warm/cold climate simulation, connect accepted heat, or select the original
strict depth-reduction loop. Fixed root profile, zero top/pond and existing signed
external-flow constraints remain. Amendments/residues, default activation and
combined companions are open; aquifer stays rejected and pond/source stays open.

## Executed science

The full literal original B1.11 uptake block and original rate/water routines,
with accepted MC-NUT01-R1 organic correction, remain independent oracles.
40-provider small and260-provider actual Richards closures execute O0/O2.
The complete original crop, reactive and mineral physical drivers execute fresh
and reproduce their admitted endpoint bytes. New actual5C->30C trajectory,
water/carrier/crop/reaction/environment rollback and retry, literal supply, whole-N,
opaque and fresh-process continuation, and18/18/10/10 malformed file negatives
per optimization pass. Both complete endpoints are byte-identical across O0/O2.

Small tests additionally exercise7.5C,0/20/40C, input-domain extremes,
nonfinite/large/stale/replayed forcing, exact equal-temperature absent-mode state,
configuration nonmutation and A/B/A. Existing -20C singular dissimilation and60C
organic rejection also occur in the fixed-temperature predecessor; these guards
are preserved, not interpreted as successful extreme-temperature trajectories.
The first failing test expected these guard cases to accept; failure is retained.
No production repair, threshold change or altered source oracle was introduced.

The physical build is measured rather than inferred from imports. There is one
fresh ordered provider build per optimization and fresh linking/native execution
for each original/new driver; no persistent cache or reused native result.

Physical costs (seconds): {"compile": 134.88511928393564, "driver_compile": 29.328628608986037, "link": 1.7449107270076638, "native": 131.2790446309955}.
Small costs (seconds): {"compile": 9.125833378973766, "driver_compile": 3.386065557016991, "link": 0.19408528599888086, "native": 0.010163715007365681}.


22 evidence controls reject incomplete/stale/foreign/corrupt science. The original
CO2, age and reactive owner CLIs pass after exact current-source eligibility.
Their original assertions execute at the immutable admitted dca8cbd8 baseline,
after this successor validates its complete changed surface and new native proof.
No incumbent source or numerical assertion is replaced by a mock. The only guard
changes admit the exact proved successor and reject unrelated source changes.

Strict documentation build passes. One complete local moving run is selected with
FCI_RESUME_MODE=OFF, frozen execution cca47b53c9d653067f3fe82257568d276087e24e,
source83f559ee097415e436a33fc9a531de93d382b99a. It must finish with a recorded
terminal result before qualification/admission. Highest low-air NOT_SELECTED_POLICY.
The work-unit status binds exact raw evidence, inputs, compiler flags, retained
failure and the next safe action. No full NUT/SOL capability promotion is claimed.


## Fresh checkout prerequisites

The first full moving attempt failed after64.586s with missing historical
F-CI93 authority15ccbf4b6bcf6895b824a68c221762bef0bc08b9; all tracked inputs
were unchanged. This is FAIL_ENVIRONMENT, not a physical PASS. It is retained.
An ordinary single-branch canonical clone does not include every independently
qualified historical owner. Fetch these exact existing commits before full replay:

```bash
git fetch origin 15ccbf4b6bcf6895b824a68c221762bef0bc08b9 5898e6616dbb6871a9f52d489038235ba1172cae fd93e50da5973f3e15c8f1b7fa57d72df6c31b72 19a67f7c398fcadbcbc9729509680a1c0c5424f3 f4f98637e963e07e2bedf7ef6acbcaab36e07e5a 48336cb7f14e9246b03c23e549fe7354a93f9e6b
```

Exact F-CI93 O0/O2 native immutable-oracle replay passes after retrieval.
No source, guard assertion, threshold or scientific candidate changed. The
complete full run restarts from the same frozen candidate in OFF mode; no
successful prefix is inherited as a complete PASS.


## Next source-qualified block

Continue with amendment/residue events on this same inventory and atomic crop
owner. Original B1.11 members are already in SWAP431_B111_AUTHORITY.tar.gz.b64:
wofost_soil_amendments.f90 SHA256
157caa9b6feafcd16f9505099874f0a8f56bc81618667d5acdafc17e40735df9;
wofost_soil_cropresidues.f90 SHA256
1f5d61e97d4a5d1dae7be604f0ed67ce5a780471d7db35236dbb0dc27d1ff8e9.
Management_soil case5 converts organ biomass kg/ha by1e-4, forms organ N fractions
from the corresponding N-loss/biomass and then calls the residue allocator.
The existing crop route books senescence as explicit output; future return to
soil must replace that output by a single internal transfer, not add a duplicate
external N input. Source amendment volatilisation is explicit external N loss.
Review grouping/fractions and original units with a literal oracle before adding
any event; this navigation is not qualification of amendment/residue semantics.


## Reproduction

Use fresh result directories and the available GNU Fortran compiler:

```bash
N_ENV_RESULT_DIR=/tmp/swap5-env-direct-new python -B tests/nut-environment/run_environment.py --direct
N_ENV_RESULT_DIR=/tmp/swap5-env-physical-new python -B tests/nut-environment/run_environment.py
python -B tests/nut-environment/verify_environment_successor.py
python -B tests/nut-environment/check_environment_controls.py
```

The direct route is routine feedback. Select full physical composition and full
moving preservation under the recorded scientific-impact/admission boundary,
not automatically after every edit. Existing stored raw proof is read separately
from newly executed science; a regenerated local output is never admission.


Terminal complete local moving preservation: PASS, OFF, exit0, wall 1690.126s. All 6316 tracked input hashes unchanged. Raw controller/logs/input manifest, failed first attempt and exact executed Git bundle are in the ADMISSION capsule. This frozen premerge receipt requires the final PR1236 canonical merge/source/tree receipt.
