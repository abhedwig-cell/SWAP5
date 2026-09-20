# TAB-HYD broad envelope gate result

Date: 2026-09-20

Status: **PREREGISTERED GATE FAILED / DIAGNOSTIC FOLLOW-UP OPEN / NO RELAXATION**

Authority: `research/tabulated_hydraulics/ENVELOPE_PREREGISTRATION.md`.

## Result

The preregistered five-scenario envelope did **not** pass.

The candidate and acceptance rules were fixed before inspection. The matrix required every analytical and direct-table route for both `SWKIMPL=0` and derivative-consistent `SWKIMPL=1` to complete normally before fidelity and performance interpretation.

Workflow run `35494493448` reached the qualification matrix and produced:

- `clay_wet_free__analytic_k0`: normal completion, 1.53 s;
- `coarse_dry_free__analytic_k0`: normal completion, 1.38 s;
- `coarse_dry_pulse__analytic_k0`: normal completion, 1.37 s;
- `loam_capillary__analytic_k0`: normal completion, 1.41 s;
- `loam_mid_free__analytic_k0`: normal completion, 1.41 s;
- `clay_wet_free__analytic_k1`: timeout at the preregistered 90 s qualification bound.

Because the first analytical `SWKIMPL=1` clay case failed to complete, the workflow correctly stopped before:

- analytical/table trajectory comparison;
- the preregistered fidelity gate;
- the cross-scenario performance benchmark.

## Interpretation

This failure is **not evidence that the direct-table representation itself failed**. The first failed case is the derivative-consistent analytical control, before its table counterpart was evaluated.

It is evidence that the combined claim

> one corrected `SWKIMPL=1` reference route is robust enough to serve as a broad hydraulic-envelope authority across these scenarios

is not established.

The gate is not redefined after seeing this result. A separate diagnostic workflow is allowed to determine:

1. whether the failure is isolated to heavy-clay/wet `SWKIMPL=1`;
2. whether analytical and table `SWKIMPL=1` fail in the same regimes;
3. how early the clay-wet difficulty appears;
4. whether the `SWKIMPL=0` analytical/table sub-envelope remains faithful;
5. whether any performance observation survives in the subset that actually completes.

Those diagnostics may classify the failure and define a future preregistration. They do not convert this failed gate into a pass.
