# PPA-MICRO02–06 and B15 moving preservation reconciliation

Status: B15 persisted PR-merge qualification passed; historical cross-workstream reconciliation remains open. PR #1077 stays a draft and canonical admission remains false.

The canonical target is `integration/f-ci-canonical` at `e5eab995ef04fc813dd644025fb0f32e4f5050a1`. The MICRO production source tree is pinned to `ac822aafd5403547a2c7ffad5c3ba02c9fa36496`.

## B15 preservation result

The PPA-WU05B15 moving preservation check in F-CI run 37429592867 stopped at its historical exact serialized-backend pin. MICRO extends the backend with an opt-in independent microscopic uptake route and extends the application bootstrap with its physical parameter and forcing carriers. The two postimages are respectively `b7d8d3a1626a82e408434b584abda2c9fe5a520c` and `32a218d3a08ca56e43ff4df35c56b3e3b67bf947`. All other B15 source postimage checks remain exact and unchanged.

The candidate F-CI guard accepts those two postimages only when the whole production source tree matches the named MICRO tree. For any other source tree, historical B15 checks still apply. The B15 runtime, additional control/finer-reference, and incumbent-preservation runners have an explicit `--micro-successor` switch pinned to the same source tree.

Local normal B15 runtime, activation, finer-reference checks, ten incumbent preservation programs, and the F-CI moving-preservation chain passed at O0/O2. Local low-air runtime passed six configurations at O0/O2 with byte-identical outputs; activation passed at O0/O2 and the 131072 refinement passed at O0. Local evidence and replay archives are in `docs/audits/evidence/PPA_MICRO_B15_LOCAL_SUCCESSOR.json` and `docs/audits/evidence/PPA_MICRO_B15_LOW_AIR_LOCAL.json`.

The exact persisted PR merge qualification passed in [PPA-WU05B run 37432003317](https://github.com/abhedwig-cell/SWAP5/actions/runs/37432003317). It tested PR head `3d0e5f2effd9bb4855ec831890ca1335cbaaba42`, merge postimage `5c3a761ecf65e5bf4c0d051c92e0d5c0f12a909b`, and the pinned MICRO source tree. All nine jobs passed, including `highest-runtime (low_air)`, which completed the actual runtime, additional controls, and incumbent preservation. This qualifies the B15 low-air successor on that exact merge postimage; it does not by itself admit the MICRO source tree canonically.

## Historical gate reconciliation

F-PE-ELASTIC09 application behavior passed O0/O2 in run 37432003002, then its original exact-single-source guard rejected the MICRO process, table binding, bootstrap, and serialized backend paths. The guard remains intact; its historical scope disposition is still with the ELASTIC09 owner.

PUB-P2E04 runs 37432003343 and 37432003316 failed compilation because the explicit module arrays omitted existing providers. Replaying the unmodified census runner on canonical preimage `e5eab995ef04fc813dd644025fb0f32e4f5050a1` reproduced the missing `mod_drainage_extended_exchange.mod`. Both runner lists now include four compile-only dependencies. Local census and Stage B/C gates pass O0/O2 on the canonical baseline and MICRO source trees with byte-identical outputs; frozen targets, tolerances, and the RossFast execution firewall are unchanged. Their persisted rerun is still required. The source-list diff and replay evidence are recorded in `docs/audits/evidence/PPA_MICRO_P2E04_RUNNER_RECONCILIATION.json`.

F-KT22 run 37432003245 fails at the external full-half outflow assertion after the two preceding EB-I25 markers pass. The unmodified gate fails at the same assertion on the canonical preimage, so this remains a separate F-KT22 owner issue.

## Admission boundary

Canonical admission stays false until the historical ELASTIC09 scope is dispositioned, corrected PUB-P2E04 workflows pass on the persisted candidate, F-KT22 ownership is reconciled, and the central F-CI owner accepts the final merge tree. No historical scientific tolerance, mass gate, or source postimage is relaxed.
