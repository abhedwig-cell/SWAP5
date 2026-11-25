# Original Frost boundary, state and calendar composition

Status: proposed current candidate; canonical admission pending. The complete
historical migration remains PARTIAL / NOT_QUALIFIED. Fixed RC3 and global
functional-family and gap counts are unchanged; those counts remain UNKNOWN.

This block composes the original no-macro Frost, Snow and SWDIVD1 implementations
with prescribed-head bottom5 and explicit plate bottom8, original initial states,
hysteresis and calendar/reset selections. Fitted implicit bottom5 remains bounded;
new implicit hysteresis2 calendars stay closed after four genuine day5 clock
resolution failures. Implicit bottom8 stays closed. The contract and recovery point
are `FROST_BOUNDARY_STATE_CALENDAR04_CONTRACT_V1.json` and `STATUS.json` in
`integration/f-ci/nomacro-complete01`.

## Actual terminal-trial defect and convergence qualification

The previous terminal conservation guard used global `qbot` before the original
Fluxes routine updated it. In an actual explicit plate Newton trial, the original
Richards convergence criteria passed and the step budget was approximately
2.87e-14 cm, but global qbot was zero while the solver candidate bottom flux was
-3.26025943986953637 cm/day. The resulting extra terminal guard forced retries
and the original minimum-step continuation without convergence.

Original `.wrn` files expose this in all16 new plate contexts (468 primary days)
and eight previously admitted batch03 plate contexts (280 primary days). The
earlier clock-only repair closed the daily budget but retained these warnings.
Those artifacts remain negative qualification evidence. The previous admission
receipt remains a historical fact; its eight affected contexts cannot supply
current convergence qualification.

`frost_boundary_terminal_trial.py` now passes the actual original
`-kmean(NN+1)*hgrad(NN+1)` trial flux to the independent terminal receipt when
`flboth` is true, and zero when it is false. It does not assign physical state,
fluxes or residuals. Existing no-argument receipt interfaces retain their
original behavior. New calendar cases use their actual day frame; existing dense
cases retain their interval receipt. The absolute 1e-10 cm terminal limit and all
original Newton criteria stay unchanged. The original qualified TimeControl is
restored; the two-edit clock workaround is superseded.

Actual Windows/Ubuntu O0/O2 qualification covers 24 affected plate contexts:
16 new configurations and eight reopened dense parent configurations. Two local
public contexts and22 original CI contexts complete their whole periods, native
and exact cold state, typed refusal and transaction controls, with zero original
convergence warnings. The selected runs are45685131290 (Ubuntu) and45685131243
(Windows), actual source36be92ae8aa7fe56b604c685d55af32c4a89f3b4; local source is
dfb4337cb5fffcf70b1fa20a672683c6ea034690. Their compiled application surface is
identical. This is evidence for the selected inputs, not universal solver
convergence for arbitrary forcing.

## Unchanged physical branches and evidence

The proposed44 new contexts comprise36 full35-day and8 year-seam12-day contexts:
1356 primary days,268 native samples,116 exact cold windows,3144 compiled
refusals and72 transaction contexts. The reopened parent contributes eight
full35-day contexts,56 native samples and24 exact cold windows. Independent
archive readers recompute budgets and validate original native, input, source,
compiler, executable, cold-output and transaction bytes. Positive trajectories
with original unconverged continuations are rejected.

Unchanged bottom5 science is reused only after16 actual current whole-source
and432 complete object comparisons under the same original compilers. Actual
raw source and explicit LF source hashes stay separate; object bytes are never
normalized. A stale dispatcher-identity assertion failed after successful build.
Its exact two-line inverse is now checked, while the original failures and build
bytes are preserved. Already compiled branches were audited without recompiling;
only the remaining branches were built. No bottom5 model period was replayed.

Raw manifests preserve the original failed scientific epochs, failed clock
counterfactuals, compiler mismatches, reader failures, genuine implicit clock
failures and the corrected scientific results. Archive locations are explicit
read-only data interfaces, never substituted HEADs, producer identities or
working directories. Source/index/working custody, inherited canonical524
evidence, current publication and actual admission are separate gates.
