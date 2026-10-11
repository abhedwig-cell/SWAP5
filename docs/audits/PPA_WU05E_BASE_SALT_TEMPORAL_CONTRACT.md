# PPA-WU05-E matrix salt and mixed-stress execution contract

Status: proposed restricted implementation contract, not production admission.
Parent: `d01bba64df778490036d5efb0bc75ab60cc5c542`.

The admitted Bartholomeus execution requires sensible soil temperature and
excludes macropores. The existing live salt prototype requires macropores.
Resolve this by adding a matrix-only dissolved-salt candidate, not by removing
the oxygen/macropore compatibility guard. Matrix salt uses theta times dz;
all water sources, final qrot and prescribed salt boundaries come from the
same Richards substep. There is one root-water receipt and a separate salt
ledger. Surface salt mixing, frost and unowned surface storage remain excluded.

An explicit backend numerical policy enables external full/half acceptance
for this new active-salt layout. It has separate positive finite tolerances
for head (cm), node water storage (cm), salt inventory (mg/cm2), and sensible
temperature (C). The maximum normalized difference determines acceptance. The transaction
threshold must explicitly equal 1 for this route; unit-bearing budgets live
only in the new policy. Extreme finite differences saturate to rejection
without floating-point overflow.
Ponding and groundwater differences use the head tolerance. Missing or
invalid state, different active layouts, and nonfinite values reject.
Temperature participates when the sensible thermal component is active.

The policy is numerical worker configuration, not a physical parameter or
restart state. An absent/invalid policy keeps matrix salt fail-closed. Existing
salt-disabled acceptance and its history certificate are unchanged. The new
policy does not imply a change to those independently admitted numerical
routes. A fresh backend must explicitly configure it again after restart.

Verify component-wise normalization, malformed input rejection, deterministic
full/half trials, conservative final-root salt removal, actual drought plus
Bartholomeus oxygen plus salinity attribution, rollback/replay/commit, and
restart with a new backend. Independently repeat the pre-existing D2/D3 gates.
The initial mixed-stress fixture is reused from the already persisted real
D2 mixed-application test, not replaced by an oxygen stub.

Affected invariants: 3, 7, 8, 13, 23. Physics configuration remains separate
from this explicitly supplied numerical policy. All qualification claims
must name their policy tolerances and tested input envelope.

## Restricted application binding (proposed)

The typed production application configuration carries this policy explicitly,
with the same disabled default as the backend. It configures the serialized
backend once at startup. Salt-active applications are restricted to ordinary
standalone bottom modes 2/7, matrix-mobile layout, no numerical continuation,
and external full/half execution. All active tiles must have a valid initial
salt component and typed Cdrain/soil-interface boundary provenance matching
their forcing slot. No groundwater-owned salt reservoir or groundwater parallel
salt admission is created. Unsupported solute layouts reject during bootstrap;
salt-disabled applications retain their existing configuration and routes.

The standalone serialized dispatcher constructs its own worker backend. Its
optional `base_salt_temporal_policy` input forwards the explicitly configured
policy to that backend before any trial. The application stores only numerical
configuration and passes it through this seam; committed salt remains solely
in physical state. Existing calls omit the new optional argument and preserve
the prior disabled behavior.
