# EB-I09 - Local Soil Water Donor Temperature Binding Contract

## Authority and purpose

Restart authority: `integration/f-ci-canonical@2a0db2524fba6e258316ce82630c60ea1c9c673a`.

EB-I09 defines a small generic binding between an already authoritative local soil-water outflow amount, an explicitly supplied donor node and the existing canonical `soil_temperature_field_view_t`.

The contract answers only one question: if positive liquid water leaves local soil through a caller-selected donor node, is a finite local soil temperature available for that donor?

It does not calculate energy and does not infer the physical route.

## Inputs

The resolver receives:

- `outflow_amount`: an already authoritative nonnegative local liquid-water transfer amount;
- `donor_node`: the caller-selected soil node that physically donates the water;
- `soil_temperature_field_view_t`: the canonical thermal field view.

The binding does not own, reconstruct, normalize or store water mass.

## Required behavior

1. A non-finite outflow amount is invalid.
2. A negative amount is invalid because this contract represents a local outward magnitude rather than a bidirectional oriented transfer.
3. Exact zero outflow requires no thermal field and no meaningful donor node.
4. Every finite positive outflow requires a structurally valid temperature view, including the smallest positive `real64` amount exercised by owner qualification.
5. There is no small-transfer tolerance or cutoff.
6. For positive outflow, `active_nodes` must be positive, the temperature array must be allocated and its size must equal `active_nodes`.
7. The explicit donor node must lie in `1:active_nodes`.
8. The selected donor-node temperature must be finite.
9. A valid selected donor temperature is copied without modification.
10. The resolver performs O(1) donor lookup and does not rescan unrelated temperature nodes on every water transfer.

## Explicit donor ownership

EB-I09 does not infer the donor node from route names, geometry conventions, top/bottom position, drainage configuration, root distribution or groundwater direction.

The caller that owns the water-transfer semantics must provide the donor node explicitly. This prevents this generic thermal binding from acquiring hidden knowledge of soil-water solver internals or application-specific process geometry.

Internal bidirectional soil-face transfers are outside this local-outflow contract. A separate oriented-transfer contract may eventually compose with an accepted internal face-transfer authority, but EB-I09 has no production dependency on such owner branches.

## Thermal-field ownership

`soil_temperature_field_view_t` remains the canonical thermal view. EB-I09 deliberately does not add temperature to `process_hydraulic_view_t`.

The soil-temperature component remains responsible for producing a valid thermal state and field view. The binding validates the view structure needed for safe indexing and the selected donor temperature needed for the requested transfer. It does not duplicate a full O(N) state-validation pass for every local water transfer.

Consequently an invalid value on an unselected node is not interpreted as a valid soil-temperature state. It is simply outside the responsibility of this O(1) transfer lookup. Upstream thermal-state creation and runtime composition retain responsibility for full-state validity.

## Trial and transaction boundary

The resolver is pure and mutates no state. It can therefore be evaluated on a trial without contaminating committed state.

However, EB-I09 does not carry transaction lineage, interval identity, candidate revision or commit receipt. It does not prove by itself that `outflow_amount` and `temperature_view` originate from the same physical trial or accepted interval.

A later runtime composition must ensure that:

- the water-transfer amount and thermal field belong to the same trial/window where required by the physical discretization;
- rejected trials never publish their thermal provenance;
- only an accepted transfer-temperature pair can enter the committed energy ledger.

## Units and physics boundary

`temperature_c` is degrees Celsius. EB-I09 performs no conversion to Kelvin and no sensible enthalpy calculation.

For routes such as drainage or bottom outward flow, local soil-water thermal equilibrium may make the selected soil-node temperature a physically appropriate donor temperature. EB-I09 does not itself qualify that route-specific control-volume assumption.

Root-water uptake additionally requires an explicit scientific decision about the location of the soil-root energy control boundary before local soil temperature can be interpreted as transported energy.

## Hard nonclaims

EB-I09 does not qualify:

- advective sensible heat or enthalpy;
- internal soil-face mass authority;
- bidirectional donor selection;
- any drainage, root, bottom-boundary or groundwater-specific donor-node rule;
- external inflow temperature;
- surface-water thermal state;
- macropore thermal state;
- snow, ice, vapor, evaporation, sublimation or phase-change energy;
- same-trial or same-window transaction lineage;
- accepted-result publication or rollback;
- MultiSWAP throughput;
- bounded-cost system behavior;
- a closed energy balance;
- independent verification;
- canonical admission.

## Owner qualification target

Owner qualification must demonstrate under GNU Fortran `-O0` and `-O2` that:

- exact zero ignores an absent view and meaningless donor index;
- a tiny positive transfer requires a valid view;
- malformed view dimensions fail closed;
- donor indices outside the active domain fail closed;
- a non-finite selected donor temperature fails closed;
- an unrelated non-finite node is not scanned by the O(1) selected-node lookup;
- a finite selected donor temperature is preserved exactly;
- negative and non-finite water amounts fail closed;
- the canonical soil-temperature and transaction sources remain unchanged;
- no source-specific or previous EB production dependency is introduced.
