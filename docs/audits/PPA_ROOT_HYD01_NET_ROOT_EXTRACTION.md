# PPA-ROOT-HYD01 preregistration

## Question

CAP01 established that the frozen groundwater-derived production trial completes for a root-active zero sink and for an exactly compensated root sink, but solver-rejects every tested nonzero unbalanced root sink.

PPA-ROOT-HYD01 separates a root-specific defect from a broader transient sink/window-scale problem before any repair is permitted.

## D1: sink equivalence and window scale

The HeadCalc residual contains both the ordinary matrix sink and `root_sink_term` additively with the same sign. D1 therefore compares two mathematically equivalent prescribed sink distributions:

- **ROOT:** `root_extraction_active=true`, sink carried by the root-sink provider;
- **GENERIC:** root inactive, exactly the same sink carried through one ordinary drainage/source-sink level.

Both use zero compensating subsurface source.

The total sink is frozen at **0.02 cm d-1**, distributed equally over the first four compartments. The hydraulic starting state is the CAP01 A3 equilibrium state: constant (h=-75\) cm with top and bottom reference flux (-K(-75\,\mathrm{cm})).

The exact duration sweep is:

[
10^{-4},;10^{-3},;10^{-2},;10^{-1},;1 \mathrm{day}.
]

No intermediate duration may be added after seeing the results.

## Numerical configuration

D1 preserves the CAP01 production-trial controls:

- `SWKIMPL=0`;
- external full-half temporal acceptance;
- temporal tolerance (10^{-6});
- hard mass tolerance (10^{-12}) cm;
- max nonlinear iterations 16;
- max backtracking 8;
- minimum substep (10^{-8}) day;
- head tolerances (10^{-12}).

No source, solver or reference mutation is permitted in D1.

## Interpretation

- Same ROOT and GENERIC pass/fail pattern: evidence against a root-specific defect.
- GENERIC succeeds where ROOT fails: root-specific provider/binding/HeadCalc discrepancy.
- Both fail only for short windows and succeed for longer windows: coupling-window numerical-envelope problem.
- Both fail across the full sweep: diagnose common transient sink/Newton execution next.
- When both succeed, accepted hydraulic state and mass response must be compared. A meaningful divergence is itself a semantic discrepancy.

D1 is diagnostic. It cannot authorize HYDRO-MEMORY Stage 0 and it cannot justify a repair by itself.


## R1: restricted root temporal-certificate extension

D1 and D2 narrowed the blocker to the temporal authority layer. The generic prescribed sink reaches the Reference-Richards temporal indicator, while the mathematically equivalent root sink is rejected only by the explicit `root-sink-envelope-deferred` guard.

A bounded repair is now preregistered before any production-source mutation.

The extension may admit **only** the concrete `b110_root_sink_provider_t`. That provider is state-independent: its `evaluate` routine returns the bound prescribed root-extraction vector and does not use pressure head or water content to alter the sink. HeadCalc inserts that prescribed root sink additively into the same residual where an ordinary sink enters.

The repair is limited to policy coverage in `mod_reference_richards_temporal_indicator`:

- recognize `b110_root_sink_provider_t`;
- verify matching node count;
- verify the prescribed vector remains bound and finite;
- leave every temporal-indicator equation and normalization unchanged;
- keep all other root-sink provider implementations fail-closed.

No HeadCalc, Richards, Feddes, transaction, tolerance or accuracy-budget change is authorized.

Qualification uses the already frozen D2 0.1-day case. ROOT and GENERIC must produce available certificates with equivalent indicator result, route, `head_inf_bound` and normalized indicator to a 64-epsilon scaled floating-point tolerance. Existing temporal owner and negative fail-closed gates must remain green.
