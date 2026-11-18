# SaltFarm Newton work: explicit conditional polishing

Proposed, not RC3: the registered SaltFarm numerical policy selects
`strict-water-half-interior-polish-v1`. Other projects retain
`strict-water-always-polish-v1`. Physical equations, original convergence,
maximum iterations, step limits and all acceptance tolerances are unchanged.
The build identity and checkpoint binding distinguish these policies.

The first original-converged Newton iterate must still pass the existing
strict cumulative water guard. An additional original Newton iterate is
retained when the residual exceeds half that guard. Inside that conservative
interior, padding is omitted. The factor one half is an explicit numerical
safety margin, not an independent error bound or a new scientific acceptance
threshold. Every completed day still passes the unchanged independent
`1e-10 cm` guard; there is no automatic fallback or acceptance of refused days.
This policy requires qualification of each application domain before selection.

The read-only 365-day RC3 trace reproduced all physical records and the native
day109 checkpoint exactly. Of35048 Newton iterations,9251 failed original
convergence,6743 failed strict mass convergence,9527 were padding and9527
were accepted. No original or mass rejection followed padding in this sample.
Nevertheless unconditional removal is unsafe: the short365-day probe passed,
but its continued trajectory refused day454 with independent residual
`1.0002533176733941e-10 cm`, while the projected guard was just inside its limit.
That failure is retained; no tolerance is widened. One conservative interior
candidate was selected instead of tuning a succession of margins.

The current candidate must pass fresh current-source O0/O2 full SaltFarm1461,
balances, exact own native/CSV/day restart, rollback and isolation, plus a
separate original431 comparison. RC3 and historical scientific dispositions
remain immutable. Current result and recovery authority:
`integration/f-ci/saltfarm-newton-work01/`.
