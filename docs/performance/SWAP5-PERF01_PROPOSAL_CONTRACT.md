# PERF01 optional accepted-step proposal production contract

Implemented bounded optional policy, with qualification described in the
[result](SWAP5-PERF01_PROPOSAL_RESULT.md). Starting canonical
`9c16572a57ada1c4b7e619bae8c1bdfb3c6f5e9c`, composed with nonlinear thermal
canonical `e61d8e107121bc31fa1d9b0eac73439af29eb76f`. Numerical execution policy, not a
change to physical equations or solver acceptance. The existing
`canonical_numerical_config_t%retain_accepted_step_proposal` remains false by
default. The column application's optional namelist field has the same name
and default; schema 1/2 inputs omitting it preserve incumbent behaviour.

When enabled, the existing external full/half transaction contract remains
mandatory and an external target selector remains incompatible. The proposal
factor, temporal tolerance, solver, retry budget, hard mass and two-half-route
acceptance tests remain unchanged. A solver rejection reported by an accepted
transaction disables proposal targeting for the remainder of that requested
canonical interval. This private policy memory resets at each new interval and
is neither physical state nor restart data. No rejected candidate is published.

An optional proposed target within the incumbent progress tolerance of the
requested endpoint is set to that exact endpoint **before** execution. Optional
completion additionally requires the accepted endpoint to equal the requested
endpoint exactly, including after fallback. A rejected final transaction must
continue or fail atomically; a near-endpoint state must never be relabelled.
Default-OFF completion semantics are preserved. No trace-consumer check changes.

Restart reproduces the same reporting-window trajectory when inputs and
numerical settings are unchanged. Restart schema is unchanged. Changing a
numerical policy between windows is not physical-state corruption, but does
not promise the same numerical trajectory.

Qualification selects direct runtime/controller and failure-atomicity tests,
existing analytic policy checks, actual water/solute column execution O0/O2,
default-OFF byte preservation against the pinned incumbent executable, exact
split restart, longer wet/dry/pulse forcing and finite-reference error/cost
comparison. Equal local tolerances are not a claim of equal global error.
Thermal joint default-OFF physical/restart/rollback/refinement evidence is rerun
because its shared runtime provider changes. Other unchanged scientific
equations retain their original source authority and predecessor qualification;
new current source admission must explicitly bind the changed runtime and fresh
impacted evidence. Existing source guards must not silently accept foreign code.

Use remains opt-in and bounded to qualified Reference external-full/half routes.
No RossFast expansion, global tolerance guarantee, regional/seasonal throughput
claim, or automatic master capability promotion follows from this work unit.
