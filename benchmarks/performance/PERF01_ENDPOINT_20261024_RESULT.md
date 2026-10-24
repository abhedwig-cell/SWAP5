# PERF01 endpoint and output-amount research,24 October2026

Both isolated4x execution limits are removed in a generated research variant.
Production sources/defaults/admission remain unchanged. Baseline canonical
5ff1486125ec7f5e3433963f49d733f1045e5eac; all earlier failures remain immutable.

Day146 replay takes0.16s to reproduce the original rejection. Hydraulic temporal
error tends to zero, but full-step Boesten SPEV/SAEV remain~0.11568cm while the
half-step state resets to zero at new ponding. Smaller dt cannot resolve this
history mismatch. The generated repair reuses the existing wet-endpoint reset
block already present for drainage, removing only its drainage prerequisite.
It invokes the real Boesten process and changes history at the wet endpoint;
water/evaporation fluxes are not recomputed. This event-semantic expansion needs
owning scientific qualification before production admission.

The independent flux slowdown is located on day2, not day1. At~1.94days the
measured output-rate discrepancy dominates (e.g.0.135cm/day), with zero uptake
error and tiny storage error. Explicit research changes ONLY the external-output
comparison to a0.001cm integrated-amount budget; uptake retains0.001cm/day and
water/GWL/Boesten retain their existing budgets. This is a different accuracy
contract, not an algebraically equivalent speed optimization.

| Full481-day native O2 | Endpoint-corrected head | Endpoint + output-amount flux |
| --- | ---: | ---: |
|1x |33.27s|1.61s|
|4x |46.05s|3.40s|

Individual observations, some overlapping build work, not paired timing medians
or an accuracy-matched4.3.1 claim. Both arms complete481days with original hard
mass gates. Selected first2/day146 O0/O2 budget/state/endpoint/restart bytes are
exact. Both1x and4x actual day240 disk continuations reproduce final state,
endpoint, restart and all241 continued daily rows byte for byte.

Accuracy consequences relative to the SAME endpoint-corrected head reference:

| Rain | Total runoff difference | Max daily runoff difference | Max storage difference |
| --- | ---: | ---: | ---: |
|1x |-0.07097mm on691.376mm|0.05191mm|0.05728mm|
|4x |-0.73857mm on4811.757mm|0.63574mm|0.62780mm|

The strict0.01mm daily screen remains FAIL. At4x day152 runoff changes7.58265 to
8.21840mm (~8.4%), followed by the opposite difference on day153. Day199 changes
from0.11750mm runoff to zero. Small whole-period differences must not conceal
those daily consequences. Positive chemistry remains excluded.

The282-member verified capsule includes diagnostics, generated source, compile
commands, raw outputs, first failures, O0/O2 subset and both restart proofs.
Next safe step is explicit production-contract/owner qualification of the
Boesten endpoint semantics and an opt-in amount-budget policy with declared
application accuracy criteria. Do not silently relax existing daily thresholds
or change plain-Boesten defaults based on this research result.
