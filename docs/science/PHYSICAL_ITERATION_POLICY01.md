# Physical-convergence proposal policy assessment

This is a numerical-policy change under investigation, not a correction to the
original NUMBIT rule. The baseline and causal observation are owned by
[SaltFarm localization](SALTFARM_PRESSURE_LOCALIZATION01.md) and
`integration/f-ci/physical-iteration-policy01/SELECTION.json`.

Original TimeControl(3) increases dt when actual NUMBIT is at most NUMBIT_CRIT,
and decreases dt when actual NUMBIT is at least MaxIt. Generated strict-water
HeadCalc adds auxiliary Newton iterations after original convergence, both to
satisfy the stricter accumulated mass gate and to polish beyond its first pass.
Those auxiliary iterations currently influence the same increase trigger.

The selected hypothesis separates only that growth trigger. The proposed counter
records the first iteration of the final consecutive original-converged streak.
Any subsequent original nonconvergence clears it. It is reset on every HeadCalc
entry, including a rejected/retried attempt. The strict gate and extra original
Newton iterations still run in their current order. Actual NUMBIT, MaxIt,
iteration histograms and high-iteration step decrease remain unchanged. Growth
using the physical count is additionally disabled when actual NUMBIT reaches
MaxIt. No guard is rounded and no iteration is skipped.

This counter is transient private-worker control context, not physical state.
It is assigned before every possible next-step use; no value is inherited from
a preceding call, day, restart or different worker. An admitted implementation
would require explicit project/build numerical-policy identity and fresh own
restart qualification. Legacy adaptive and configured daily actual-count policies
must remain explicit selectable identities, with no failure-driven fallback.

One private SaltFarm discriminator activates the alternative on day1009, preserving
all1008 preceding daily heads/stocks/flows/uptake exactly. Its corresponding
read-only paired control is already saved; no control trajectory is repeated.
The local candidate passes all unchanged water/solute guards, native6.013s.
The hosted paired candidate is run43553332658 on carrier
c48aef4603cae77e9cc6fe004b1423e21bc0dbda. It does not replace a supported BUILD
or load a foreign checkpoint, and is not production qualification.

Next decision depends on that paired result. A material reduction would justify
an explicit candidate policy, followed by relevant fresh O0/O2 complete named
trajectories, exact own restart, unchanged balances and coupling/source refusals.
It would not prove scientific equivalence or authorize relaxing any original
criterion. A failed or immaterial result must remain visible and lead to a
simpler strategy rather than repeated threshold adjustments.
