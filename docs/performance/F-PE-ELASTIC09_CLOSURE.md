# F-PE-ELASTIC09 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@4a45a599093c6ed6da458dc35fbb71f462439ef4`

Merged PR:
`#758`

Admitted production file:
`src/runtime/mod_fmr_production_application_bootstrap.f90`

## Admission summary

F-PE-ELASTIC09 admits the existing soil/material ELAS ownership chain through
the production application bootstrap:

`elasticity_active + cofgen(24,:)`
-> admitted ELASTIC08 runtime materialization
-> admitted ELASTIC05 typed constitutive ELAS.

No ELAS value, default, parser syntax, timestep rule, convergence rule or
transaction policy is introduced.

## Qualification authority

The bounded application qualification passed on the pre-admission production/test
postimage in run:

`36527206646`

job:

`109272764791`.

Named passes:

- `F_PE_ELASTIC09_A1_BOOTSTRAP=PASS`;
- PPA-WU01 default-off owner preservation;
- `F_PE_ELASTIC09_A3_HETEROGENEOUS=PASS`;
- `F_PE_ELASTIC09_A4_FAIL_CLOSED=PASS`;
- `F_PE_ELASTIC09_A5_DYNAMIC_IDENTITY=PASS`;
- `F_PE_ELASTIC09_O0_O2=PASS`;
- `F_PE_ELASTIC09_SOURCE_SCOPE=PASS`;
- `F_PE_ELASTIC09=PASS`.

The clean current-canonical extraction was merged through PR #758.

## Post-merge replay adjudication

A replay of the clean branch was still running when PR #758 was admitted:

run `36528296760`, job `109276070500`.

That replay completed with an overall workflow failure.

All substantive application/runtime gates passed again:

- A2 default-off preservation: PASS;
- A1 active bootstrap: PASS;
- A3 heterogeneous ownership: PASS;
- A5 application/direct-runtime identity: PASS;
- A4 fail-closed invalid/composed routes: PASS;
- O0: PASS;
- O2: PASS;
- O0/O2 identity: PASS.

The only failing marker was:

`F_PE_ELASTIC09_SOURCE_SCOPE_FAIL=[]`.

This is not a missing production delta on the tested branch. It occurred because
the source-scope check uses the moving
`origin/integration/f-ci-canonical` merge-base, and canonical already contained
the ELASTIC09 production commit by the time that final check executed.

After admission, the expected current-canonical production diff is therefore
empty.

## Blob identity

The admitted canonical production file and the clean qualification postimage
have the same Git blob:

`4b0d76dc96cc35b3bb5da02420563a3b656b5f2f`.

Compared refs:

- current canonical;
- clean qualification head
  `9531e94e6eff795ea03f78fbbb65c66792569f65`.

Therefore no production source changed between the qualified clean extraction
and admitted canonical state.

## Classification of the red replay

`EXPECTED_POST_MERGE_SOURCE_SCOPE_COLLAPSE`.

It is not classified as:

- numerical regression;
- application-bootstrap regression;
- mass regression;
- ELAS ownership regression;
- transaction regression.

The original pre-admission source-scope gate already passed while the production
delta still existed relative to canonical.

## Final admitted envelope

Supported:

- serialized Reference/default MvG;
- explicit `elasticity_active`;
- node-local finite nonnegative `cofgen(24,:)`;
- heterogeneous ELAS per layer/node;
- normal production application bootstrap;
- hard mass qualification;
- default-off preservation.

Still fail closed:

- ELAS + KSATEXM;
- ELAS + direct retention/AHL;
- ELAS + tabulated hydraulics;
- ELAS + hysteresis.

Not admitted:

- universal ELAS value;
- `1e-6 cm^-1` default;
- MvG-to-ELAS pedotransfer;
- legacy parser restoration;
- stress-dependent mechanical ELAS model.

## Closure

F-PE-ELASTIC09 has no remaining production-software action.

The remaining work belongs to the separate physical-parameter research line,
currently F-PE-ELASTIC10/BHR-GT mechanical-target acquisition.
