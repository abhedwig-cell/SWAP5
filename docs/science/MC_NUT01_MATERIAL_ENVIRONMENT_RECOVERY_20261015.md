# Simultaneous material and prescribed-temperature recovery

MC-NUT01-MATERIAL-ENVIRONMENT, [PR1238](https://github.com/abhedwig-cell/SWAP5/pull/1238).
Baseline canonical `fb311dabd16266409deb394c381fe26086a64d03`.
Status: `integration/audits/MC_NUT01_MATERIAL_ENVIRONMENT_STATUS.json`.
Contract: `MC_NUT01_MATERIAL_ENVIRONMENT_CONTRACT_20261015.md`.

Two optional final arguments forward the existing typed prescribed soil
temperature through material staging into the existing crop/soil day and actual
Richards joint application. This supplies the missing simultaneous forcing API.
Existing material chemistry and rate functions, WOFOST81 fixation, water and
private soil/crop owners, parameter identities and joint codec remain unchanged.
No stored last forcing, pending material queue, cursor or new N inventory.
Materials, water, organic/mineral pools and crop publish atomically after the
existing day and pre-material whole-N budget succeed. Absent forcing must preserve
the original material endpoints exactly; an empty material batch with forcing
must equal the explicitly forced non-material day exactly.

Small real crop/soil closure42 and physical Richards closure260 are measured
at O0/O2 with bounds and invalid/zero/overflow traps. Both original material and
new simultaneous-forcing drivers run fresh. The exact source archive supplies
unmodified original amendments/residues and original rate/water routines plus
the separately admitted R1 organic correction and literal management uptake.
New5C and30C material days compare all eight organic pools, biomass/humus,
NH4/NO3 and actual crop supply. Invalid forcing, late material/crop/water failure,
retry, replay, A/B/A and full state nonmutation remain hard assertions. Stale
forcing rejects on the next day, including fresh-process continuation. Existing
complete opaque/native restart and19 invalid native payload cases execute for
both old and new profiles per optimization.

The first physical attempt is retained: its new test incorrectly compared the
explicit5C empty material route with an unforced20C comparator. It correctly
failed endpoint equality after native explicit material/oracle/restart assertions
completed. The comparator now receives the same forcing. Production was unchanged;
fresh final builds and native executions establish the scientific result.
The original absent-forcing material endpoints compare bytewise with the
immutable PR1237 coexistence capsule, rather than with a regenerated expectation.

Current source, complete raw science inputs/events, compiler flags and measured
compile/driver/link/native costs are in status and its SHA-bound evidence capsule.
The executed science Git bundle is retained. Original36 material evidence/source
controls execute at the exact admitted baseline; new simultaneous controls reject
foreign source/reference/test delta, partial/stale/failed/raw-corrupt science,
unchecked or missing ABI builds, missing direct/actual native execution, altered
literal source and default/empty/restart endpoint changes. Existing ordinary
CO2/age/crop/environment CLI routes delegate only after strict successor proof.

Select exactly one full local moving OFF after stable science and guards are
persisted, about1650s under the existing four-level admission contract. Inspect
its terminal exit, full input hashes and marker; no running run is a PASS.
Highest low-air is NOT_SELECTED_POLICY; no hosted run is claimed. Metadata-only
closeout does not rerun unchanged science. Read status for actual preservation
state and PR1238 for final canonical merge/tree/source identity.

Coverage receipt: `integration/audits/MC_NUT01_MATERIAL_ENVIRONMENT_COVERAGE_20261015.json`.
No master branch/count/disposition promotion. Full amendment/residue migration
remains active. Next dependency-ready scope: automatic actual WOFOST81 senescence
and harvest residue debit/return with a single internal whole-N transfer. Do not
relabel already externalized crop N loss as extra external material input.
Explicit calendar policy, file/default activation, accepted heat/profile coupling,
lifecycle and simultaneous solute companions remain separate. Pond/source stays
open and aquifer stays rejected. Reconcile live refs and existing owner work
before opening another candidate.
