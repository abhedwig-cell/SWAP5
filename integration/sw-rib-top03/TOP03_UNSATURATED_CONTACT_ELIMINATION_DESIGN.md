# TOP03 nonlinear contact elimination: bounded proposed contract

Date: 2026-10-02. Proposed research design, not an admitted production interface.
Prerequisites: explicit-layer decision, stationary-layer preregistration and
failed current-K face audit with numerical-policy reconciliation.

## Required local problem

Use the existing synthetic constitutive K(h)/theta(h), including its actual
cutoff, and actual finite layer thickness. Fix the external total head
Etop=H+L, the first matrix-node pressure hs at zs<0, geometry and layer origin.
Solve for layer pressures h1..hN. The matrix interface uses the same harmonic
series resistance, not a saturated matrix face:

Ginterface = 1 / (0.5 dzN / KN(hN) + 0.5 dzs / Ks(hs)).

Upward signed flux is qinterface=Ginterface*(Es-EN), with Ei=hi+zi.
Reconstruct the common interface total head independently from both sides:
EI=EN+qinterface*0.5 dzN/KN = Es-qinterface*0.5 dzs/Ks.
At the fixed interface elevation zero this is also its pressure head.
The top face retains the comparator's declared arithmetic saturated/node
boundary conductance; internal faces retain its weighted harmonic law.

A stationary local problem requires qi-q(i+1)=0 with every Ki evaluated at
that same candidate layer pressure. Solve it independently inside the contact
closure, with no global Richards-policy change. Merely adding zero-capacity
nodes to the existing SWKIMPL=0 solver does not implement this requirement.
The candidate-K face audit must pass before it can serve as a stationary
oracle. Existence, selected constitutive branch, residual and boundedness
must be checked; do not assume uniqueness across a constitutive discontinuity.
A numerical failure remains unavailable evidence, never an admissible flux.

## Stateful layer and transfer ownership

For an evolving layer use each compartment equation

dzi*(theta(hi_candidate)-theta(hi_origin))/dt + qi-q(i+1) = 0.

The origin is the same immutable accepted layer state for every outer trial,
Newton evaluation, retry or recomposition. At a candidate matrix pressure the
local solve may produce a tentative layer profile; it cannot advance its own
origin. Rejected outer candidates discard that profile. Accepted full/half
branch composition must compose both transfers and the layer state.

External input Iexternal=-integral(qtop dt) and matrix input
Imatrix=-integral(qinterface dt) differ by DeltaWlayer:
Iexternal-Imatrix=DeltaWlayer. The layer must have exactly one storage owner.
External pond/body storage remains separately owned under its own contract.
Never return Imatrix as the total external receipt while omitting DeltaWlayer,
and never conceal layer storage inside imposed pond depth H.

For a local Newton linearization partition layer and matrix unknowns. The
condensed matrix Jacobian is D-C*A_layer^(-1)*B. Its boundary derivative must
come from the same local residual/flux closure, not an unrelated fitted R.
The original R=L/Ksat and saturated Darcy solution are mandatory limit controls.
No default resistance, measured parameter envelope or portable speed claim is
supplied by this synthetic construction.

## Why production remains outside this change

The current dynamic provider evaluates pressure/theta/pond at a point. Its
result carries soil top flux and surface terms; it has no explicit candidate
layer-state/owned layer-storage contract. Binding an immutable local origin
for test-only evaluations is feasible. Adding hidden mutable layer state to
that provider would violate trial/rollback/restart ownership. A stateful
production reduction therefore requires an explicit owning state/candidate
contract and acceptance/receipt composition reviewed by canonical authority.
Keeping a physical explicit layer within the soil profile is the available
reference representation, subject to its own profile and physical envelope
qualification. The research diagnostic's fixed water content is not such a
physical representation.

## Next preregistered implementation boundary

Implement only a standalone/test-only local nonlinear layer solver and a
matched stateless stationary contact evaluator. First qualify its saturated
limit, candidate-K local face closure, two-sided interface-head identity,
origin/starting-guess behavior and O0/O2 replay. Then compare it with the
explicit reference at independently ready time/space levels, preserving the
existing top, matrix-interface, bottom, water and head budgets. A separate
stateful reduction must retain DeltaWlayer and subsequently qualify state,
accepted branch composition, receipts and restart. No production solver or
shared interface change follows automatically from this design.
