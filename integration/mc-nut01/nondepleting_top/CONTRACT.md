# MC-NUT01 nondepleting signed aggregate and competing sinks

Locally qualified candidate, canonical admission pending. The existing finite-donor
fallow route and default route retain their contracts. This additive mode is
explicit `nondepleting_top`, mutually exclusive with `finite_donor_top`.

Historical authority: immutable SWAP431 B111 archive, Wofost_SoilWaterN and the
current admitted daily exchange demand/supply and juvenile selection. The
negative aggregate remains the prescribed historical loading, not pond chemistry.
For each demand/supply branch, the same equation is solved:

`(theta + rho*K) dC/dt = positive_loading + signed_production + qtop*ctop/dz - (dtheta/dt + qout/dz + tcsf*qroot/dz + rate*theta_average)*C`.

The existing regular finite-donor analytical solver evaluates this equation by
combining the negative part of constant production with the prescribed top sink,
and root loss with outflow. These are algebraic transformations only. The branch
is accepted exclusively if C_end > 0 and depletion_time == dt, unmet == 0.
For constant forcing and linearly positive capacity a positive initial and end
concentration preclude an interior zero crossing. Otherwise the entire day is
rejected. Even an exhausting unused demand/supply candidate rejects: this is a
conservative domain restriction, not a claim of complete active-crop coverage.

On success production is restored to the original signed prescribed value;
actual top equals requested top and unmet is zero. The historical NH4-first crop
selection, juvenile factor, nitrification transfer, NO3 denitrification and
organic inventory transfer are retained. Negative net mineralisation is admitted
only if both forms and all invoked branch candidates remain nondepleted. The
existing pool owner and whole crop/soil N residual gates remain authoritative.
No tolerances, physical water fluxes, state/restart schemas or defaults change.

Affected invariants: 3, 7, 13, 21, 23, 25, 26, 30. The runtime commits complete
water/crop/soil candidates together. Invalid chemistry discards the water trial.
Existing native restart identity includes committed physical state; the mode is
per-day forcing, supplied again after restart just like historical_top_water.

Not covered: allocation after exhaustion among top extraction, crop uptake and
immobilisation; automatic snow/pond N binding; full historical NUT migration.
