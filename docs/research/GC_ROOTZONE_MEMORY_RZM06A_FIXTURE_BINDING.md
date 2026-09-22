# GC-RZM06A fixture and observable binding

Date: 2026-09-22  
Status: BOUND, IMPLEMENTATION PREREGISTRATION NEXT  
Production source: read-only

## Selected real-SWAP carrier

Use the existing F-GC44 B110 serialized-reference real-Richards carrier, not a
new production path. It already provides transactional committed state,
checkpointed corrector trials, fixed groundwater-head materialization,
accepted bottom exchange, and mass diagnostics.

The current carrier initializes a deterministic hydrostatic-like profile from
H0_CM=-75 cm and exposes the full committed physical arrays internally:
pressure_head(:), water_content(:), ponding_depth and groundwater_level.
The existing Python bridge does not expose those arrays, so RZM06 requires a
research-only diagnostic extension to the F-GC44 bridge. Production modules
remain untouched.

## Frozen observables

Profile water inventory:
  W_profile = sum_i water_content(i) * dz(i)

Root-zone inventory:
  W_root = sum over nodes whose cell support lies within the upper 30 cm.
If the B110 grid has a cell intersecting the 30 cm boundary, weight that cell
by geometric overlap rather than assigning the whole cell.

Vertical-distribution metric:
  M1 = sum_i water_content(i)*dz(i)*z_mid(i) / W_profile
using the same z convention as the carrier. It is an observable only.

Interface response:
  E_c = accepted bottom_outward_exchange_native converted consistently to m
for reporting. Physical trial flux retains the existing outward-SWAP sign.

Interface head:
  H_c = the fixed groundwater-head control passed through the existing
materializer. Do not substitute physical%groundwater_level.

## State preparation

RZM06A will add research-only bridge entry points that create two independent
committed origins by executing and accepting antecedent real-Richards windows.
The antecedent forcing is selected before probe response is inspected.

First pair:
- DRY/WET ordering is generated with equal-magnitude top-boundary perturbations
  in opposite temporal order over two antecedent windows.
- The final probe uses identical zero top forcing and identical H_c.
- If the current fixed-flux provider cannot be reconfigured without production
  edits, stop RZM06A as infrastructure-blocked and introduce a research-only
  provider in a separately preregistered repair.

Matched-total-water pair:
- Candidate antecedent sequences are enumerated prospectively.
- Select the first pair in enumeration order satisfying
  |Delta W_profile| <= 1e-6 m water equivalent and
  |Delta M1| >= 1e-4 m.
- Probe E_c is not evaluated until the pair is frozen.
- If no pair qualifies, report NO_MATCH rather than loosening tolerances.

Local tangent:
- H*=the carrier's accepted fixed-interface reference head for the frozen pair.
- deltaH=1e-6 m, already inside the previously demonstrated local live band.
- central difference from fresh immutable checkpoint trials.

Probe duration:
- 1e-4 day, matching the established F-GC44 default live carrier.

## Integrity gates

Mass residual must satisfy the existing carrier mass gate.
Repeated trials from one checkpoint must be bitwise/equivalent within existing
carrier tolerance.
State-observable extraction must not mutate the committed origin.
No probe result may participate in pair selection.

## Scope decision

RZM06A first qualifies H1-H4. H5 management-memory is deferred to RZM06B
because the current F-GC44 carrier has no qualified management-forcing entry
point. This prevents introducing a new forcing mechanism merely to make the
real-SWAP experiment convenient.
