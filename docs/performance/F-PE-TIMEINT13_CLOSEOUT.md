# F-PE-TIMEINT13 closeout — second-order predicted-conductivity BDF2

Date: 2026-09-29

Final status:

`CLOSED_WITH_CONSERVATION_BLOCKER`

## What is now established

1. The current SWAP temporal method is not inherently limited to first order.
2. Fully implicit BDF2 is second order on smooth fixed-flux trajectories, but costly on dynamic-top.
3. Extrapolated-conductivity BDF2 retains near-second-order convergence on smooth fixed-flux trajectories without the strong endpoint K coupling.
4. Its dynamic-top nonlinear work is close to KLAG on completed cases.
5. The remaining blocker is no longer primarily KIMPL nonlinear cost.

## New blocker

The tested BDF2 formulation does not preserve the current accepted-interval water-balance identity in its ordinary form.

SWAP5's transaction/mass architecture expects an accepted interval to publish:

`storage_end - storage_start = integrated_in - integrated_out`

within the qualified tolerance.

A generic multistep derivative such as:

`a0 theta_{n+1} + a1 theta_n + a2 theta_{n-1}`

is not automatically equivalent to that consecutive-state interval identity.

This issue must be treated as a discretization/accounting design problem, not hidden by loosening mass tolerances.

## Required successor

`F-PE-TIMEINT14 — conservative multistep Richards formulation and interval mass contract`.

TIMEINT14 should answer:

1. can BDF2 be written in a conservative increment form that preserves the physical accepted-interval storage balance;
2. alternatively, can the multistep residual be separated from a physically exact flux ledger without changing the solved endpoint;
3. what flux quadrature/order is required for second-order temporal consistency;
4. whether cumulative multi-interval conservation remains exact even if individual BDF2 derivative equations use history;
5. whether transaction publication can retain the existing interval mass semantics unchanged;
6. whether the smooth second-order evidence survives the conservative formulation.

No adaptive controller should be reopened before this is resolved.

## Production boundary

No production source change.

LEGACY_NUMERICS remains production default.
