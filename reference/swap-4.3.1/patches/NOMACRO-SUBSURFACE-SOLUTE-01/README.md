# Original no-macro subsurface solute input correction

**Implemented candidate; full reference and SWAP5 coupling qualification pending.**
This is not a global B1 promotion. Active macropore branches are unchanged and
are not selected for execution.

The actual original concentration perturbation is recorded at
`integration/f-ci/nomacro-complete01/ORIGINAL_CHEMICAL_AUDIT.json`:2.4cm subsurface
water ignores concentration0/20, while the surface positive control adds48mg/cm2.
Original CDE includes neither the nodal irrigation mass source nor its ledger.

The correction consumes actual original `qssdi(i)` in cm/day, original `cirr` in
mg/cm3, actual solute interval in days, and original compartment thickness in cm.
The existing conservation equation receives the source in conserved bulk mass
`cmsy`, before the original concentration conversion. The matching amounts enter
both existing cumulative/intermediate irrigation ledgers. The allocation is
literal per supplied compartment, preserving original interval irrigation; it is
not normalized by node count or soil thickness.

The shared production evaluator has an independent one-provider O0/O2 driver
with exact units/mass, A/B/A, input nonmutation and refused-output preservation.
The original CDE scratch arrays contain only freshly derived source amounts;
they are initialized on task1 and overwritten each active solute substep. They
are not physical state and introduce no persistent format. The original CDE
equations, numerical controls, surface sources and inactive source arithmetic
remain unchanged. Current SWAP5 chemical SSDI preflight refusals remain active.

Before integration, qualify the exact corrected original module on water-only
macro-disabled input, with active chemistry: surface/subsurface0/20 controls,
explicit per-node conservation, strict chemical balances and source-absent
preservation. Then qualify the actual SWAP5 caller, accepted/discarded state,
source/ledger correspondence, own native restart and relevant process coupling.
Pristine original water/chemistry defects remain separate; original output is
not automatically a scientific oracle.
