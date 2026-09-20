# TAB-HYD-001: tabulated conductivity derivative is inconsistent at table endpoints

Status: **CONFIRMED CURRENT/PUBLIC IMPLEMENTATION DEFECT; BOUNDED CANDIDATE QUALIFIED ON PUBLIC/TRANSITIONAL LINEAGE**

Scope: research finding only. No production or B1 admission is made by this document.

## Finding

For `SWSOPHY=1`, the conductivity used in the Richards residual is explicitly extended as a constant outside the tabulated theta range:

- at and above the wet endpoint, `hconduc` returns the last tabulated conductivity;
- at and below the dry endpoint, `hconduc` returns the first tabulated conductivity.

The corresponding `dhconduc` path is inconsistent with that residual function:

- near/at the wet endpoint it returns the artificial value `1.0d+08`;
- below the dry endpoint it still calls the tabulated derivative evaluator and can address table index 0.

This violates the already-admitted SWAP-011 Jacobian-consistency rule: where the residual uses `K(h)`, the Jacobian must use the derivative of that same implemented conductivity relation.

For the endpoint extension actually used by `hconduc`, K is locally constant. Therefore its consistent endpoint derivative is zero.

## Reproduced consequences

### Wet endpoint

In the 31-day Hupsel table case with `SWKIMPL=1`, the unmodified implementation timed out after 20 s. Replacing only the wet endpoint derivative sentinel `1e8` by zero made the case complete in about 0.17 s.

A broader candidate, zero derivative at both tabulated endpoints, completed both `SWKIMPL=0` and `SWKIMPL=1` for the full 2002-2004 Hupsel period in the pre-strangler executable test route. The dedicated candidate workflow also verified zero wet- and dry-endpoint derivatives with the current-public wrapper under bounds checking.

### Dry endpoint

With a table whose dry endpoint is `h=-1e7 cm`, a wrapper probe at `h=-1e8 cm` obtains finite endpoint-clamped theta, C and K. The unmodified `dhconduc` path nevertheless enters the table evaluator and, with bounds checking enabled, reaches `sptab(...,0)`.

This is not a consequence of a non-finite constitutive curve. It is a mismatch between the endpoint policy of K and the endpoint policy of dK/dh.

## Candidate correction

For `SWSOPHY=1`:

```fortran
if (theta >= theta_table_max - tolerance) then
   dhconduc = 0
else if (theta <= theta_table_min + tolerance) then
   dhconduc = 0
else
   dhconduc = derivative_of_interpolated_table
end if
```

This candidate intentionally changes only derivative behavior outside the interpolated interior. It does not change tabulated theta(h), K(h), C(h), table preprocessing, or interpolation inside the table domain.

## Why zero is the bounded candidate

This is not chosen as a numerical damping trick. It follows from the existing residual-side endpoint contract. If `hconduc` holds K constant beyond an endpoint, then the derivative of that implemented K(h) extension is zero there.

The existing `1e8` value instead creates a Jacobian term that is not the derivative of the conductivity used in the residual.

## Cross-check against the analytical SWKIMPL=1 control

A later audit step found an analogous mismatch in the default analytical MvG route (TAB-HYD-003): the residual clamps K to Ksat over a finite near-saturation interval while its `dhconduc` branch continues to use the derivative of the unclamped MvG expression.

This matters for interpreting the table candidate. The previously unmodified analytical `SWKIMPL=1` trajectory was itself inconsistent and differed from analytical `SWKIMPL=0` by more than 11 m in maximum Hupsel GWL.

After applying the same residual/Jacobian rule independently to both representations:

- corrected analytical K1 versus corrected table K1: GWL max abs `0.00043 cm`;
- GWL RMSE `1.54e-5 cm`;
- drainage and TACT match at written output precision;
- DSTOR max abs `1.41e-10 cm`.

This supports, rather than weakens, the zero derivative at the table's constant endpoint branch. The value `1e8` was not reproducing a required analytical reference behavior; it was one of two inconsistent near-saturation Jacobian policies.

## Qualification boundary

The first three bounded qualification items have now passed on the public/transitional lineage:

1. bounds-checked wrapper probes give dK/dh = 0 at both wet and dry endpoint extensions;
2. the full-period table `SWKIMPL=1` Hupsel case completes normally;
3. the full-period `SWKIMPL=0` versus `SWKIMPL=1` difference has been quantified.

Before any production/B1 admission, the remaining requirements are:

4. exact-B0 source binding, or an explicit authority decision that the correction belongs only to a later/current source lineage;
5. broader regression evidence that interior table behavior and `SWKIMPL=0` are unchanged;
6. an explicit numerical acceptance envelope for the non-identical but now mutually consistent analytical/table `SWKIMPL=1` trajectories relative to `SWKIMPL=0`;
7. separate handling of the current typed-input reachability gap, which is independent of this derivative defect.

The candidate must not be described as an acceleration result. Its purpose is Jacobian consistency and functional correctness.
