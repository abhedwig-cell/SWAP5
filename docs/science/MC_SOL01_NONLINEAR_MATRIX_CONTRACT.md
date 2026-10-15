# MC-SOL01 nonlinear matrix successor

Status: proposed production successor; not canonically admitted.
Baseline: `ee2d84498bec23c55449f5d7fd8ebd9ecb7bfdde` (PR #1228 and its
initialization correction). Recovery: the `nonlinear_successor` field in
`integration/audits/MC_NUT_SOL_TRAJECTORY3_STATUS.json`.

## Scope and ownership

Extend only the existing matrix companion's accepted exponent domain to
`0.5 <= frexp <= 2`. The existing equilibrium operator, literal-order transport,
water-face reconstruction, reaction accounting, joint trial/commit, and native
restart codec remain the owners. No state field, schema, shared interface,
water/crop/root owner, forcing policy, or accepted WOFOST81 law changes.
Affected invariants: 3,4,7,9,13,21,22,23,30, unchanged in meaning.

Freundlich storage is
`M/dz = theta*C + rho*Kf*Cref*(C/Cref)**frexp`.
Units remain cm, day, mg/cm3 concentration, mg/cm2 mass, rho in g/cm3 and
Kf in cm3/g at reference concentration Cref. Cref has concentration units;
the ratio in the exponent is dimensionless. No mass is created by changing
theta; the existing source-bound decay uses ending theta and pre-node C.

The donor #1117 corrected inverse is already present in canonical production
but nonlinear application was explicitly excluded by #1228. This successor
does not replace it or silently assert exact B1.11 trajectory identity.
The pinned `SWAP/solute.f90` hash remains
`2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2`.
Its lines 441..449 contain two known numerical differences: the near-linear
shortcut and the relative fixed-point iterate stop. Neither is a mass-closure
certificate. Qualification must compare the actual extracted historical
inverse, the unchanged source transport loop, and an independent inverse.
Expected differences require explicit owner/regie acceptance; this is not a
new immutable B1 snapshot or an admission of the entire donor.

## Discriminating qualification

1. Small real-Fortran process closure: actual canonical sorption operator versus
   independent real128 damped Newton inversion, plus closed quadratic solutions
   for exponents 0.5 and 2, non-unit Cref, zero sorption, zero mass, changing
   storage, and invalid parameters. Source-extracted historical inversions
   demonstrate the two expected differences rather than hiding them in tolerance.
2. Extend existing drivers, not a parallel runtime: exponents 0.5, 0.8, 1,
   1.0005, 1.5, 2 through actual Full Richards accepted traces over multiple
   windows, signed root/drain/bottom fluxes, decay, water/chemical balances,
   rejection/retry/prefix rollback and opaque continuation.
3. Actual joint water/chemical application and fresh-process native disk restart
   for every exponent at O0/O2; reject altered exponent/Cref even with same ID,
   and invalid physical file contents with valid recomputed CRC.

Use the existing matrix runner with `MATRIX_NONLINEAR=1`, and its `--process-only`
entry for daily feedback. No persistent cache. Expected process cost <5s;
targeted physical build about 120s plus native 10s per exponent, measured anew.
The 237-source water closure is justified by the private real accepted trace
and backend, not by chemistry alone. Complete moving preservation belongs at
the stable admission boundary under protocol rule8 and central F-CI authority;
it costs about 1825s. It is not routine process feedback. The existing exact
source guard must be reconciled by that authority before canonical admission.
No blanket inheritance of full-FCI PASS and no highest low-air stress selection.

## Exclusions and next blocks

Pond/rain/irrigation/SSDI/macro, aquifer mutation, age, Soil-N/crop-N,
root salinity feedback, default bootstrap/multicolumn and portable restart stay
excluded. No whole master row is promoted. Existing master #1072 and the
NUT/SOL owner #1117 retain their wider authority and blockers. Next independent
SOL block is water-age amount/production on accepted carriers; next NUT block
is mineral NH4/NO3 inventory plus transport and whole-N restart before reactions.
