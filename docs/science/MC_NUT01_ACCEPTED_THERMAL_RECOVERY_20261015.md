# MC-NUT01 accepted thermal recovery

Status: scoped science and shared-owner preservation qualified; final admission
is established by PR #1246's merge receipt.
Baseline `cd64c5044a29643a068c6151720f76b2e70f570d`, branch
`work/nut-accepted-thermal-20261015`. Owning record:
`integration/audits/MC_NUT01_ACCEPTED_THERMAL_STATUS.json`.

Implemented: source-literal strict-depth temperature reduction; one detached
certified accepted heat profile; explicit backend observation opt-in for heat
without salt; atomic water/heat/crop/N/material/pending day; opaque complete-owner
restart; native thermal tags with and without pending residues, original grid
certificate and heat/history continuation. Physical formulas, crop fixation,
water inventory and old BASE native tags remain unchanged.

The actual final physical execution is
`999d9580fcdd38d43ff48d454a8d1784db6df72b`, source tree
`fe0747d5ec38d1383666376f5e0162373faefcc0`. Later changes add verification and
metadata only. The fresh small execution is `96e8a4288385767e0373420d5ff01ad136c50018`
with the same production tree. Both optimization builds used 269 real production
providers for the accepted-state composition. The small reducer uses one.

Completed evidence: 23 reducer cases per optimization; unchanged calendar
process/day/BASE joint assertions plus thermal physical composition; original
organic/mineral/supply expectations, whole-N, material and pending-residue
balances, rollback/retry/replay; manual/calendar endpoint identity; continuous,
opaque and fresh-process native identity; 22 CRC-correct/corrupt decoder controls;
14 explicit trace-policy/initial native restart cases. BASE native bytes equal
the canonically admitted amendment-input capsule at both optimizations. Actual
source-selected soil temperatures are about 8.00383 C and 27.10066 C on the two
thermal days; the fourth node is excluded by the original strict depth rule.

Final composition costs: provider compile 148.30 s, driver compile 26.82 s,
link 0.90 s, native 194.56 s; total selected events 370.57 s. This is a targeted
composition cost, not a full-F-CI timing or portable speed claim. Policy and
negative controls reuse the verified live objects and compile their own driver;
the complete final composition is fresh at O0 and O2. Failed small/development
compile/link/preflight observations remain in the capsule, including the attempted
same-session recovery; none is promoted to PASS.

The earlier draft stopped at the amendment-input guard's
`foreign/incomplete input delta` rejection. That boundary is now reconciled by
`MC_NUT01_THERMAL_ADMISSION_RECONCILIATION_20261015.md`: all three shared files
project to their exact baseline bytes on the reviewed default paths. The full
moving scientific body also remains byte-identical after removing only the
declared eligibility additions. NUT dispatch and CO2's original physical and
additional-owner evidence assertions remain active. The existing CO2 metadata
still reports `qualified: false` with 28 physical programs; no new CO2 admission
is inferred from the successful evidence validation.

The final current controls pass 289 cases: all 245 historical controls, the 30
thermal evidence controls and 14 source/default/moving-body controls. The
source/evidence-only owner gate passes. The selected final executions are at
`66c10f635a881a5d5fc8a44280ad045bbec2f69f`, without production or physical-driver
changes. Costs are recorded separately in the reconciliation capsule. No new
Fortran compilation or numerical execution, full F-CI, highest low-air or
Actions execution was selected. This does not relabel old full-F-CI evidence as
new thermal or current-source full qualification.

Verification entry points:

```sh
python -B tests/nut-thermal/verify_thermal_evidence.py
python -B tests/nut-thermal/check_evidence_controls.py
python -B tests/nut-thermal/verify_thermal_successor.py
python -B tests/nut-input/check_input_controls.py
bash tests/fci/run_fci_canonical_p2e05_moving_preservation.sh --nut-thermal-owner-only
```

The scoped verifier deliberately reports `canonical_admission: false`.
The status record supplies the exact capsule member count, decoded size and SHA256.
The status record binds every production/test postimage and all raw source,
compiler, driver, endpoint and negative-control evidence.
The capsule also preserves a Git bundle through the actual local scientific
execution commits, with canonical baseline as prerequisite. Thus connector-based
publication can preserve their original commit identities as well as the final
reviewable source tree. Extract `execution/history.bundle` and fetch it in a
repository containing the baseline if the original execution refs are needed.

Remaining scope: harvest/reset and rotation, complete legacy/default activation
and broader companion options after this bounded admission.
Pond/source remains open; aquifer remains rejected. Do not modify the separate
active MC-CROP01 root/oxygen or MC-SOL01 surface-input workstreams.
