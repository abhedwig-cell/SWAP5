# F-PE-NLGLOB14Z38 closeout — zero-waste persistent manager fast path

Date: 2026-09-30

Final status:

`Z38_PERSISTENT_MANAGER_TIMING_REGRESSION`

Qualification authority:

- workflow run `36771542143`;
- persistent timing job `110078896933`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z38 removes most of the Z37 allocation/copy penalty but does not make the frozen sub-microsecond manager microbenchmark faster than full.

Geometric-mean timing ratio improves from about:

- Z37: 1.3017;
- Z38: 1.1156.

The structural work ratio remains 0.796875.

Steady-state measured execution performs:

- zero request-buffer reallocations after setup;
- zero full-candidate reallocations after setup;
- zero workspace shape reallocations after setup.

## Interpretation

The zero-waste direction is validated: persistent ownership removes a large fraction of the overhead.

However, the remaining benchmark kernel is only about 0.14 microseconds per full operation. Fixed manager/view/materialization overhead therefore dominates by construction.

Further optimization against this isolated TRIDAG microkernel would not answer the practical SWAP Heritage question.

## Direct successor

Open:

`F-PE-NLGLOB14Z39 — compiled Richards solve-service manager benchmark`.

Z39 must measure the manager around an actual compiled Richards solve-service cost scale, including:

- constitutive evaluation;
- residual/Jacobian construction;
- nonlinear iteration;
- active-dimension workspace;
- reduced tail reconstruction;
- manager publication overhead.

Use a small fixed fixture set only.

Do not start a broad trajectory or BOFEK campaign.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z38

BRANCH: `research/f-pe-nlglob14z38-persistent-manager-fast-path`

RESULT POSTIMAGE BEFORE CLOSEOUT: `39777579c581ae8ed61c9ae66aadd218d18472d8`

QUALIFICATION STATUS: `Z38_PERSISTENT_MANAGER_TIMING_REGRESSION`

NEXT SAFE STEP: Z39 realistic compiled Richards solve-service timing.

## Production boundary

No production default change.

`LEGACY_NUMERICS` remains production default.
