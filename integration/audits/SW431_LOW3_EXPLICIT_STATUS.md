# SW431-LOW3-EXPLICIT status

WORKSTREAM: SWAP 4.3.1/B1.11 coverage closeout  
CAPABILITY: SW431-LOW3-EXPLICIT  
IMPLEMENTATION BRANCH: work/swap431-low3-explicit-20261007  
BASELINE: 19d7ce86f71c7fa5fd3ed2c65a91dc705921f714  
QUALIFIED CODE HEAD: 61a63bd4f5a00ca465dab0243e58b42e6d88d6d3  
PRIMARY QUALIFICATION RUN: 37612263087  
QUALIFICATION JOB: 112762086766  
ADMISSION PR: #1090  
CANONICAL MERGE: 1e85f726bd5794110a60f1d2fbf22b12b72afbda  
EVIDENCE PR: #1091  
CURRENT RECORDED CANONICAL: d395ca3decf03e7149dbf8d65dc9ad8946826f3a  
STATUS: REPAIRED / canonical admitted

## Scope

Ordinary explicit `SWBOTB=3, SwBotb3Impl=0` is canonically admitted using:

- profile-derived groundwater level from the current trial-start pressure-head profile through the qualified B1.11/CALCGWL-compatible projection;
- `SHAPE_3` transformed groundwater level;
- saturated profile resistance from the groundwater-table node through the profile bottom using saturated conductivity;
- forcing-owned `DEEPGW`, `RIMLAY` and optional `QBOT4` through the existing admitted Cauchy temporal control;
- trial-local materialization of the resulting `qbot` through the already admitted explicit-flux solver route.

The existing implicit LOW03-A Cauchy route remains a distinct owner and is preserved.

## Source authority and semantics

The lower-boundary source authority is
`integration/audits/F-MIG431_LOWER_BOUNDARY_B111_SOURCE.json`, member
`SWAP/boundbottom.f90`, SHA-256
`5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e`.

The admitted explicit law preserves:

```text
gwlmean = hdrain + shape_3 * (gwl - hdrain)

do while (gwlmean > ztopcp(node) .AND. node > 1)
    ...
end do

cvalprof =
    saturated_fraction_of_crossing_node / Ksat(crossing_node)
    + sum(dz(node) / Ksat(node), deeper nodes)

qbot = (deepgw - gwlmean) / (rimlay + cvalprof) + qbot4
```

The strict `>` is normative. Exact equality with `ztopcp(node)` keeps that node selected.

## Ownership and invariants

- CALCGWL/profile groundwater level is derived from the current trial-start physical pressure profile.
- `DEEPGW`, `RIMLAY` and `QBOT4` remain owned by the existing typed Cauchy control/proposal.
- The explicit route resolves a trial-local flux and then uses the existing prescribed-flux Richards surface. It does not introduce a new implicit Richards boundary law.
- No new committed physical state is introduced.
- Restart-v1 is unchanged.
- No second groundwater owner is introduced.
- No second mass booking is introduced.
- Existing implicit mode 3, prescribed-qbot and nearby unsupported selector combinations remain preserved or fail closed.
- The superseded draft PR #1088 is not an independent implementation route. Its source-reconstruction intent is retained, but its stored-GWL trial path is replaced by the source-faithful profile projection.

## Qualification evidence

GitHub Actions run `37612263087`, job `112762086766`, completed successfully on the exact admitted code head
`61a63bd4f5a00ca465dab0243e58b42e6d88d6d3`.

The persisted evidence record is
`integration/audits/F-MIG431-LOW03-EXP-P0_QUALIFICATION.json`.

The successful qualification covers:

- explicit Cauchy component source oracle at O0/O2;
- CALCGWL/profile-groundwater projection at O0/O2;
- strict equality boundary semantics;
- interior, saturated and below-profile projection behavior;
- heterogeneous saturated conductivity profile resistance;
- `QBOT4` composition and admitted temporal Cauchy control;
- production bootstrap as its own ordinary explicit Cauchy profile;
- transactional runtime and hard whole-column mass closure;
- existing implicit mode-3 preservation;
- nearby unsupported bottom-mode fail-closed behavior;
- shortened retry and rollback without publication;
- replay identity;
- failed retry with no published candidate;
- missing-history fail-closed behavior;
- fresh-backend restart continuation identity.

Representative persisted PASS markers include:

```text
SW431-LOW3-EXPLICIT-COMPONENT=PASS
SW431-LOW3-PROFILE-GWL=PASS
LOW03EXP_APPLICATION_GATE=PASS
LOW03EXP_SHORTENED_RETRY_ROLLBACK=PASS
LOW03EXP_REPLAY_IDENTITY=PASS
LOW03EXP_FAILED_RETRY_NO_PUBLISH=PASS
LOW03EXP_HISTORY_MISSING_FAIL_CLOSED=PASS
LOW03EXP_FRESH_BACKEND_RESTART_IDENTITY=PASS
LOW03EXP_PROGRESS_GATE=PASS
SW431_LOW3_EXPLICIT_APPLICATION_O0_O2=PASS
SW431_LOW3_EXPLICIT_RUNTIME=PASS
SW431_LOW3_IMPLICIT_PRESERVATION=PASS
```

The earlier run `37600022448` failed before production-application qualification and is historical development evidence only. It is superseded by the later green qualification above.

## Canonical reconciliation

PR #1090 merged the functional capability to `integration/f-ci-canonical` at
`1e85f726bd5794110a60f1d2fbf22b12b72afbda`.

PR #1091 then persisted the stronger qualification record and merged at
`d395ca3decf03e7149dbf8d65dc9ad8946826f3a`.

A dependency-surface comparison from the qualified code head
`61a63bd4f5a00ca465dab0243e58b42e6d88d6d3` to recorded canonical
`d395ca3decf03e7149dbf8d65dc9ad8946826f3a` shows no production, solver, runtime or test changes for this capability; the only file delta is the added qualification JSON. The qualified evidence therefore remains applicable to the current recorded canonical surface.

## Claim ceiling

This closes ordinary explicit `SWBOTB=3, SwBotb3Impl=0` only.

It does not broaden:

- unrelated lower-boundary selectors;
- external groundwater ownership;
- Restart-v1 schema;
- common Richards residual/Jacobian semantics;
- RossFast;
- SWKIMPL1;
- macropore;
- frost;
- MICRO;
- MIGMAC;
- sensitivity semantics.

## Disposition

`REPAIRED / canonical admitted`.

No further implementation or qualification work is required for this bounded capability unless a later canonical change touches its recorded dependency surface or new source evidence invalidates the admitted contract.
