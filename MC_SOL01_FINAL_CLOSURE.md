# MC-SOL01 final closure

Status: bounded canonical implementation is admitted; the four full historical capability envelopes below remain explicitly parked. This is not a claim of complete SWAP 4.3.1/default equivalence.

Review baseline: `integration/f-ci-canonical` at `e122ff8f682584620717e97ab24ce07933dd0923`; production source tree `282e4504c8d1d31e9cdfa37041b6b06a48a90588`. Review date: 2026-10-19. The final admission receipt is in the existing `integration/audits/MC_NUT_SOL_TRAJECTORY3_STATUS.json` record. The existing master is on `work/swap431-master-coverage-20261006`, PR #1072. It is not a canonical full-coverage admission.

## Source authority and capability balance

The immutable B1.11 archive is `integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64`. Its `SWAP/solute.f90` SHA256 is `2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2`. Literal historical transport and age loops remain the source oracle. Two accepted differences must not be called historical identity: the mass-consistent nonlinear inverse under PR #1230, and positive runon/runoff pond chemistry under PR #1304.

The eight rows below are the existing master entries for subsystem `solute`, including the historically impossible macropore combination. No second census is created. ADMITTED means the bounded registered claim, not unrestricted historical selector compatibility. None of these eight rows is QUALIFICATION_ONLY.

| Existing capability | Master disposition | Actual production and admission | Final disposition of remaining envelope |
| --- | --- | --- | --- |
| SW431-MACRO-SOLUTE | NOT_APPLICABLE | Historical input reader rejects SWSOLU > 0 with macropores. | Excluded historical combination; SWAP5 prototypes do not change that finding. |
| SW431-SALT-TRANSPORT | ADMITTED | Mobile dissolved advection/diffusion/dispersion, signed faces, root TSCF, drain and bottom receipts. PPA-WU05E admission; reactive matrix successor PR #1228. | Closed within registered matrix domain. |
| SW431-SALT-SORPTION | ACTIVE_MIGRATION, explicitly parked remainder | Real matrix application, linear and nonlinear Freundlich exponent 0.5..2, PR #1228/#1230. | Wider reader exponent 0..10, nonlinear pond composition, dynamic accepted thermal coupling and complete default-file activation are not admitted. Production constructor rejects 0.49999 and 2.00001 in the real driver. Preserve the existing bounded route. |
| SW431-SALT-DECAY | ACTIVE_MIGRATION, explicitly parked remainder | Source-order temperature/moisture/depth decay including nonlinear inventory, PR #1228/#1230. `temperature_active=false` retains historical zero temperature factor. | Dynamic accepted temperature ownership across water/solute restart and full historical/default activation require a separate composition contract and physical qualification. No aquifer dependency. |
| SW431-SALT-AQUIFER | REJECTED | No admitted evolving aquifer owner. Exact SWBR source has the documented numnod+1 bounds defect and lacks an aquifer bulk-density input defining rho*KFSAT+POROS. | Deliberately excluded; no invented bottom-soil density or reservoir law. |
| SW431-SALT-POND | ACTIVE_MIGRATION, explicitly parked remainder | One matrix pond-mass owner, rain/irrigation/deposition, evolving pond, runon/runoff, infiltration, non-exporting evaporation, atomic retry and V2 restart. PR #1234/#1256/#1257/#1258/#1304. | Nonlinear pond sorption is rejected by the actual route's `frexp /= 1` guard. Snowmelt/exfiltration and complete default/bootstrap/multicolumn activation remain outside the admitted application. Simultaneous age/reactive/N companions are not inferred. |
| SW431-AGE-TRACER | ACTIVE_MIGRATION, explicitly parked remainder | Soil age and positive pond age on actual accepted Reference traces, aged external input, exactly-once handoff, joint transaction and fresh-process restart. PR #1233/#1309, supplemental #1315 and CI repair #1317/#1321. | Complete evaporative drying is scientifically blocked under the retained no-evaporative-age-export convention. Snow/exfiltration age, general outputs/default/multicolumn and simultaneous companions are not admitted. |
| SW431-SALT-BOTTOM-C | SUPERSEDED | Typed immutable interval bottom concentration supplies shared-drain, independent constant or externally resolved time-varying concentration. | Closed by admitted external forcing replacement; no dynamic SWBR reservoir implied. |

ACTIVE_MIGRATION remains the truthful master classification of the four *full* historical envelopes. Their former generic missing-implementation descriptions are replaced by exact bounded admissions and parked remainders. This closure does not silently change the capability denominator or promote an incomplete historical claim. There is no remaining unassigned implementation step in the bounded Reference closure.

## Physical and state contracts

Only converged, hydraulically accepted substeps may advance chemical/age state. Net qtop cannot reconstruct simultaneous gross rainfall, irrigation, evaporation and runoff. Reference-private accepted receipts carry gross-source provenance; shared solver and optional RossFast contracts are preserved.

The water owner owns pond depth. Matrix `pond_mass` is the sole committed surface chemical store. Surface scratch receipts are not a second persistent pool. For infiltrating water, the admitted B1.11 cutoff is qtop < -1e-6 cm/day. The SWAP5 positive-runoff extension mixes available mass against ending pond volume plus infiltration and runoff volumes, then books exactly one soil transfer and one runoff export. Evaporation removes water but no solute. Noninfiltrating runoff uses ending pond plus runoff volume. Dry deposition and retained solute survive the admitted dry/rewet route.

For a whole water/solute interval, internal faces and pond-to-soil transfer cancel. Change in soil plus pond mass equals external rain/irrigation/runon/deposition and bottom/drain inflow minus runoff, root, drain, bottom and transformation sinks under the admitted signs. Water storage independently closes against all accepted water receipts. Rejected numerical or chemical trials, including rejected accepted-prefix carriers, publish neither water nor constituent state. Smaller retry starts from the same committed owners.

Surface age is an amount in cm day; mean age is amount divided by water depth. Age production is the accepted timestep times mean starting/ending pond volume. Explicit external water age enters with its actual volume. The exported infiltration-age amount is passed once to the native soil-age top boundary. The joint pond/soil balance cancels that internal transfer; it must not be added through both a source receipt and the boundary again.

The retained surface-age convention exports no age through evaporation. Therefore positive age stock cannot survive at zero water with a finite mean age. Complete evaporative dry-down is rejected, not clipped or converted into an invented dry store. See `docs/science/MC_SOL01_SURFACE_AGE02_QUALIFICATION.md` and its exact dry-limit executable. This is a limitation of the accepted convention, not a RossFast obstacle.

## Qualification and restart evidence

PR #1309 qualifies all twelve requested positive-pond criteria: positive pond/runon/runoff/infiltration, stored and external nonzero age, accepted ageing, exact soil handoff, closed combined balance, rejected trial with no committed mutation, smaller retry, multiple accepted substeps and independent-process continuation. Its actual two 86.4-second windows report combined age residual about -3.25605e-15 cm day. The O0/O2 fresh and uninterrupted endpoint SHA256 is `7afefa2a28a99e5b7ca05bf92e5402005329ce419b41ce8e07548aedc0955831`.

The supplemental two-day four-pulse study in PR #1315 includes 259424 accepted steps on its finest case, 12 fresh-process continuations across meshes/optimizations and observed decreasing endpoint changes when the *actual* accepted maximum timestep halves. Finest combined age residual is about 3.98792e-13 cm day. These are controlled four-node-column results, not field or seasonal validation or a formal order proof.

Restart contracts are deliberately distinct. Matrix chemical restart V2 preserves the sole pond mass and configuration identity while V1 remains compatible. `S5AJ0001` continues to encode the water/soil-age payload. Surface-age `S5PA0001` and that payload are bound together by one CRC-protected `S5AT0001` snapshot. A temporary file is flushed/fsynced, one POSIX rename publishes the complete generation, then directory durability is synced. The three logical owners are decoded and validated before commit. Independent loose files must not be recombined as if they were one generation. Existing SIGKILL before/after rename and corrupt/truncated/overlong/identity/overwrite controls demonstrate complete-generation recovery. Scope is same-platform POSIX, serialized ownership; no portable binary ABI or concurrent writers are admitted.

| Existing admission evidence | Result and exact scope |
| --- | --- |
| PR #1304 final head 0cc3fe1f; runs 39115709736, 39115709442, 39115709818 | SUCCESS: F-CI96, preserved old F-ROSS12 wiring, actual O0/O2 positive-gross Reference chemistry/rollback/V2 continuation. |
| PR #1309, run 39153649970 | All three jobs SUCCESS; source-bound positive-pond/soil age, snapshot and incumbent preservation. |
| Surface-age full moving local execution 27d0cfa2 | PASS, 459.151946 s, resume OFF, 6912 inputs unchanged; separately qualified atmospheric-N coexistence. |
| CI repair full moving execution 9de996d4 | PASS, 781.268452 s, resume OFF; exact later parser/guard coexistence retained. |
| PR #1321 actual merge 6153b540; runs 39168835955, 39168835957, 39168836087, 39168835956, 39168835969 | All five automatic workflows SUCCESS. Canonical selection/feedback success does not mean skipped broad jobs reran. |

No new RossFast development, aquifer implementation, highest low-air stress or unrelated solver qualification is selected. Full F-CI is inherited only through the current source/evidence validators and unchanged relevant scientific dependency surfaces. This closure changes documentation/registration, not production science or tests.

## Current-session execution

Pending completion of the selected local current-head runs. This section is replaced by terminal results before closure admission; no pending run counts as PASS.

## Parked work and re-entry criteria

1. **SORPTION remainder:** preserve exponent 0.5..2. Widening to the full legacy reader domain requires an explicit numerical envelope, independent inverse, actual accepted-water transport and restart/rollback evidence. Nonlinear pond composition also requires qualifying the real pond route, which currently rejects any exponent other than one.
2. **DECAY/thermal remainder:** replace no immutable parameters implicitly. A future live-temperature adapter must bind actual accepted temperature, identity, rollback and independent-process restart to the chemical owner; validate the historical SWHEA=0 zero-factor branch separately from dynamic thermal composition.
3. **POND/application remainder:** keep unsupported snowmelt/exfiltration fail-closed. Any new source needs an accepted gross water receipt and constituent boundary contract; default-file/bootstrap/multicolumn activation needs real production reachability and end-to-end balances. Existing runon/runoff is already closed and must not be reopened.
4. **AGE remainder:** changing evaporation-age export or allowing complete drying requires a scientific decision about whether the state represents physical water age or a nonvolatile tracer moment, followed by an independently derived balance and dry-limit/restart qualification. Default/output/multicolumn or simultaneous companions need separately selected application evidence. Strictly positive pond and existing zero-pond routes are already closed.

These remainders are parked separately in the existing master/workunit records. None authorizes a new research line in this closure, and none is converted to ADMITTED by documentation. Aquifer stays rejected; RossFast stays optional only on its previously admitted domain.
