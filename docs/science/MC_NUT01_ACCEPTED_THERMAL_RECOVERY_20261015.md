# MC-NUT01 accepted thermal recovery

Status: scoped local scientific qualification; shared-owner reconciliation open.
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

Canonical admission is not claimed. The unmodified amendment-input source guard
rejects `foreign/incomplete input delta`, because this unit introduces a new
backend observation interface and shared native-codec/matcher postimages. Do not
weaken or bypass that guard, and do not treat its old full-F-CI evidence as current
postimage qualification. Review the explicit opt-in, reconcile relevant owner
guards with retained physical/default-policy assertions and exact dependencies,
then use the normal expected-head admission boundary. No full F-CI, highest
low-air stress or Actions execution was selected or dispatched for this unit.

Verification entry points:

```sh
python -B tests/nut-thermal/verify_thermal_evidence.py
python -B tests/nut-thermal/check_evidence_controls.py
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

Remaining scope: shared-owner admission reconciliation first; then harvest/reset
and rotation, complete legacy/default activation and broader companion options.
Pond/source remains open; aquifer remains rejected. Do not modify the separate
active MC-CROP01 root/oxygen or MC-SOL01 surface-input workstreams.
