# TAB-HYD-001: tabulated conductivity derivative is inconsistent at table endpoints

Status: **CONFIRMED CURRENT/PUBLIC IMPLEMENTATION DEFECT; CANDIDATE FIX UNDER QUALIFICATION**

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

A broader candidate, zero derivative at both tabulated endpoints, has also completed both `SWKIMPL=0` and `SWKIMPL=1` for the full 2002-2004 Hupsel period in the pre-strangler executable test route. Final qualification of that candidate is tracked by the dedicated derivative-clamp workflow.

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

## Qualification boundary

Before any production/B1 admission, all of the following remain required:

1. successful bounds-checked wet and dry endpoint wrapper probes;
2. full-period executable evidence that the table `SWKIMPL=1` route no longer stalls;
3. characterization of the numerical difference between table `SWKIMPL=0` and `SWKIMPL=1`;
4. exact-B0 source binding, or an explicit decision that the correction is admitted only against a later/current source authority;
5. regression evidence that interior table behavior and `SWKIMPL=0` are unchanged;
6. separate handling of the current typed-input reachability gap, which is independent of this derivative defect.

The candidate must not be described as an acceleration result. Its purpose is Jacobian consistency and functional correctness.
