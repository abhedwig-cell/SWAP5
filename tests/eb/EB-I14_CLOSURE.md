# EB-I14 Bottom Advective-Energy Quadrature Contract Closure

## Decision

`QUALIFIED_DESIGN_FREEZE_PENDING_EXACT_HEAD_CI`

EB-I14 closes the scientific/numerical contract needed between the qualified EB-I13 accepted-route carrier and a later production Joule evaluator. It intentionally contains no production implementation.

The authoritative closure condition is a successful `EB-I14 bottom advective energy quadrature contract` workflow on the exact branch HEAD containing this document. A green run on an older commit is supporting evidence only.

## Closed decision

For the current reference water discretization, the accepted model-advance bottom amount is a terminal-flux rectangle:

`Q_b = -q_b,end * Delta_t`.

Therefore local outward liquid-water sensible energy shall use the terminal local bottom donor temperature from the same accepted model advance:

`T_adv = T_bottom,end`.

With explicit constant-property energy configuration,

`E_b = 0.01 * rho_w * c_p_w * Q_b * (T_adv - T_ref)` [J/m2],

with positive `Q_b` and positive `E_b` oriented outward from SWAP.

This is a first-order discrete-consistency rule. It is not presented as an exact continuous-time integral or as a higher-order quadrature.

## Fail-closed boundary

Exact zero transfer contributes exactly zero and needs no temperature.

Every nonzero transfer needs donor thermal provenance. For inward water the donor is external. Current EB-I13 deliberately does not invent that external temperature, so an inward nonzero sample without explicit same-sample external thermal provenance makes the complete bottom-energy result unavailable/incomplete. Hydrologic acceptance remains unchanged because this optional accounting term is not yet governing thermal physics.

## Rejected alternatives

The frozen current-reference production rule may not use:

- aggregate outer water times final outer bottom temperature;
- an arithmetic endpoint temperature average combined with the current terminal-flux water amount and described as a consistent higher-order method;
- reconstructed temperatures from extra Richards or thermal solves;
- local soil temperature or zero enthalpy as fallback for missing external donor water temperature.

A different jointly qualified water-and-temperature quadrature remains allowed as a future solver/numerical policy.

## Architecture disposition

`EB-I14_ARCHITECTURE_AUDIT.json` records PASS or PRESERVED for all thirty SWAP architecture invariants. The design introduces no second kernel, no persistent column energy history, no file I/O, no calendar assumptions, no MODFLOW-cell composition knowledge and no second water ledger.

The executable contract gate additionally requires that the branch contain no production delta relative to the qualified EB-I13 restart authority.

## Next workunit

The next production workunit may implement a candidate-scoped bottom sensible-energy evaluator. It must independently prove the implementation gates listed in `EB-I14_CONTRACT.md`, including sample-wise Joule algebra, exact-zero behavior, fail-closed inward provenance, reference-gauge identity, adversarial rejection of the aggregate shortcut, zero additional physical solves, unchanged hydrology/restart and bounded O(Nsample) cost.

Accepted energy commit/publication and external groundwater/deep-vadose temperature physics remain separate later work unless independently qualified in that implementation workunit.
