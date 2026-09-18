# ROM-1A-R2 frozen-policy reachable-state library

D3 qualified the strict-first local-plus-total research Reference policy on the
complete discovery population D01-D08 before any held-out history was exposed.

R2 now runs the original ROM-1A library design unchanged: the same B01 seed, the same
12 histories, the same 64 steps per history, the same 0.0008-day timestep, the same
discovery/held-out split and the same outputs.

The D3 policy is frozen. H01-H04 may test it; they may not tune it. If a held-out
interval produces a failure class outside the frozen policy, R2 is a no-go. A later
diagnostic may explain that no-go, but ROM-1A may not adapt its policy or history
definitions to the held-out result.

B14 remains sealed. No reduced coordinate, POD basis, memory variable or closure model
is selected in R2.
