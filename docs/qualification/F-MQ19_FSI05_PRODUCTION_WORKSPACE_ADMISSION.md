# F-MQ19 — F-SI05 production workspace seam admission

## Decision

F-MQ19 admits the exact qualified F-SI05 production HeadCalc workspace seam as downstream MultiSWAP qualification evidence.

The admitted F-SI05 qualification head is `0227ae94edc3364b013f831f1efa6aaccac29b11`. Its committed production materialization is `1fe1bf4790955594290ba1233d5684542799bf9e`; the tested implementation checkpoint is `56c21448a2a0be716d497ac34db8c5eec60dd246`; the documented final-postimage verification is `11b3138e05b1a5c59033134e870f6ffb58e6a9f6`.

## What is newly admitted

F-SI05 moves the production HeadCalc main Newton/Jacobian/tridiagonal scratch and the alternative band-solver scratch into the F-SI reference workspace. The production adapter passes an existing worker/job-owned Richards workspace into HeadCalc while the legacy one-argument HeadCalc call remains source-compatible through a call-scoped local workspace.

The focused executable gate establishes preimage identity at O0 and O2 for both the normal tridiagonal route and a forced band-fallback route, explicit-workspace versus legacy-call identity, workspace poison/reset, ABA repeatability, focused route/iteration identity and common-workspace 1/2/4/8-thread isolation.

This directly strengthens the production-source prerequisites for F-MQ P06 and P19.

## Fail-closed boundary

No full 35-row matrix promotion is made. F-SI05 explicitly does not qualify:

- full reference-Richards reentrancy;
- parallel real HeadCalc execution with 1/2/4/8 workers;
- real multi-column HeadCalc interleaving;
- removal of legacy worker `SAVE` or all cross-call HeadCalc history;
- a full real SWAP interval;
- complete unrounded SWAP water-balance identity;
- production reference admission;
- production MultiSWAP runtime.

Therefore the formal coverage remains 27 synthetic executable rows, 0 complete real-physics rows and 0 production-runtime rows.

## F-VQ11

F-VQ11 was observed at `7584f0c38d407913304eea05fd343f2f7fef31cc`, but its status is still pending and unqualified. F-MQ19 does not consume it. F-MQ19 is source-bound directly to F-SI05's own qualified evidence.

## Next dependency

F-SI06 is the primary next dependency: resolve legacy-worker/cross-call history ownership and qualify real HeadCalc order independence and 1/2/4/8-worker reentrancy on admitted reference routes. Full P10/P11/P16 promotion still separately requires a reference-derived SWAP interval fixture with hard unrounded complete mass accounting. Production runtime qualification remains dependent on F-MR.
