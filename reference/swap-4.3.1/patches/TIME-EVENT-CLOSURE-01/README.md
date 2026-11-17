# TIME-EVENT-CLOSURE-01: bounded corrected-reference history

Status: actual native component qualified at O0/O2; integrated model replay and
admission pending. This entry does not promote a global B1 snapshot.

The original TimeControl(3) can declare day end before accepted durations span
the full day. Snow(2) has already updated storage for one full day; Integral(3)
uses the shorter accepted duration. The source-bound Q observer reproduces the
day21 water/drainage failure: 2025accepted steps sum0.9999999999595638day;
snow storage minus integrated net flux accounts for the extra mass residual to
1.1828645701816853e-15cm. Historical source and failing rows remain unchanged in
`integration/nomacro-coverage01/BLOCK_Q_OBSERVATION_RAW.tar.xz`.

The minimal patch gives case3 the same near-event comparison already present
in cases1/2: `dt+dtCrit > dtEvent`. It keeps the original dtCrit1e-8day and all
physics, solver and mass criteria. The expected difference is that a proposal
less than dtCrit short of an event extends to the event, before physical fluxes
are integrated. No post-hoc stock or mass correction is applied.

`run.py --reference-work <prepared-original> --output <new-directory>` compiles
the complete original TimeControl separately at O0/O2 and links its actual
native closure with a small public-interface driver. `COMPONENT_RESULT.json`
records source/provider/driver/object/compiler/executable identities, commands,
timing and original/corrected outcomes. Two demonstrated deficits close exactly;
three ordinary/exact/overshoot controls remain identical; both optimizations
agree. This gate does not establish full trajectories or scientific equivalence.

Only a bounded, explicit numerical-policy successor may consume this correction
after the failed model prefix, full trajectories, exact native restart and
conservation gates pass. Immutable B0, prior reference files and frozen release
tags are unchanged. This follows ADR-0005 and the Q recovery/contract records.
