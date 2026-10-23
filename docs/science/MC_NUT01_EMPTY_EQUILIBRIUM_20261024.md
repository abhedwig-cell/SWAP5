# Empty homogeneous mineral equilibrium

MC-NUT01 bounded candidate, baseline03c1c7a41d66924e2d974275cd14d4bdc4101047.
The owning contract is `integration/mc-nut01/empty_equilibrium/CONTRACT.md`;
canonical admission requires its separate actual-merge receipt.

The original WaterN equation is homogeneous when concentration, production and
all boundary loading are zero. Its solution, interval mean and all fluxes are
exactly zero. An empty ammonium pool does not preclude nitrate uptake. The
signed-top adapter previously rejected even this zero-supply state. Its
strict-positive guard now has an exact homogeneous exception, retaining all
depletion-time and unmet-sink checks. An exhausted demand candidate must lose
the tie against an exactly zero supply candidate; its partial production and
averages cannot be selected. Exact cancellation of mineralisation and prescribed
juvenile uptake also leaves zero net production and concentration; that mineral
source goes directly to the plant. All other equations and thresholds remain exact.

Independent DOP853, direct unmodified historical WaterN, actual daily exchange,
current HIST and crop/Richards/N composition establish only this bounded domain.
With both boundary concentrations zero, changing the water aggregate cannot
exhaust nitrogen. That coupled negative instead tests invalid chemical temperature
after actual water, plus stale-environment and water rejection tests. Whole-state
rollback and fresh-process restart remain required. The actual negative reaction
fixture from PR1412 remains unchanged. Allocation after genuine competing-sink
exhaustion and snow/persistent-surface N remain open; full NUT is not closed.
