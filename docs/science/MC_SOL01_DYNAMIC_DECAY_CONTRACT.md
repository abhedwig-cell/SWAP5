# MC-SOL01 dynamic accepted-temperature decay

Status: proposed composition contract, not canonical admission.
Baseline: `83defb1a6a7a9f4d2fcd862faf73a21ad621072a`.

The existing B1.11 sorption, transport and temperature/moisture/depth decay
operators remain the scientific implementation. This successor supplies an
actual, node-resolved restricted-heat endpoint to those operators. It does not
reinterpret the immutable configured temperature vector as mutable state.

One explicit coupling interval first advances Reference water and restricted
soil heat into a detached committed carrier. Its endpoint temperature profile
is held constant while the existing chemical operator consumes precisely that
interval's accepted water receipts. This is endpoint operator splitting, not
historical substep-temperature identity. Interval refinement is a qualification
condition; arbitrary long intervals and seasonal accuracy are not inferred.

The original committed water/heat and chemical owners are assigned together only
after transport, reaction, mass closure and endpoint alignment succeed. A failed
water, heat or chemical trial publishes neither owner. Immutable chemical
parameters, including the original temperature vector, remain byte-identical.
`temperature_active=false` separately retains the source's zero-decay factor.

The bounded domain is one matrix column, no surface input/pond, no macropores,
snow, frost, aquifer, crop/N/age companions or RossFast extension. Existing
Reference trace and restricted-heat contracts remain authoritative. Root,
drain and bottom receipts are the existing accepted water receipts. Geometry,
heat activation, clocks and certified parameter identity must agree.

Invariants affected: 3 (separate state/parameters), 7 (atomic rejection),
13 (mass closure), 21 (reuse physics), 23 (no solver-policy change),
25 (preserve Reference). No incumbent implementation or shared interface is
changed. Disk restart must carry water, heat, chemical inventory, temporal
history and identities as one generation before independent-process admission.

Qualification selects a real production driver at GNU O0/O2, changing thermal
boundaries, literal source-order decay control, heat-off control, chemical
overdraw rejection and smaller retry, hydraulic rejection, geometry and identity
negatives, independent process restart and measured interval refinement.
Unchanged incumbent physical providers retain their existing authority; added
composition is not admitted by a module graph alone.
