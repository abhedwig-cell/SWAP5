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

The discrepancy is specifically reconstructed phase storage versus the carried
`cmsy`, not a claim that the historical independently advanced `cmsy` ledger
loses this mass. With theta=0.2, rho*Kf=0.1, Cref=1, cmsy=0.7 and initial C=2,
the actual extracted inverse gives reconstructed-storage residuals
`2.5502022033996319e-4` (n=2, eight iterations) and
`9.8872359150958822e-5` (n=1.0005, linear shortcut). The existing production
inverse closes the same fixtures below 1e-14. Those are expected numerical
differences, not historical equality obtained by loosening transport tolerances.

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

## Executed evidence (2026-10-15)

Primary local execution `16fc62e8dee34e2d02d45c159c8a71a5d44e48b0`
and strengthened joint driver `a85facff905e6299acffd2f3c11bfeea0a03f295`
are recoverable in the evidence Git bundle. Four-file process closure passes
7,218 independent cases per optimization. All six physical exponent scenarios
pass at O0/O2, with exact stdout and endpoint identity, source-order transport,
signed boundary/root/drain/decay balances, rejected-prefix rollback and retry,
opaque continuation and fresh-process joint native restart. Every exponent
also rejects nine corrupt/physical file variants, altered exponent and Cref.

Primary measured costs: compile128.234076s, link0.600389s, native60.644979s.
The stronger joint assertions explicitly compare both chemical mass stores
after rejection and close the multi-window balance. They pass using487
hash-verified unchanged provider artifacts per optimization in the same live
qualification, compiling/linking only the changed driver:5.635491s compile,
0.283380s link,45.929738s native. Every selected executable runs afresh; this
is not a persistent cache or inherited scientific PASS. Complete reproduction
uses the normal runner and compiles both final drivers.

All240 final science inputs are sealed. Original admitted linear stdout,
endpoint/restart hashes and module interface remain identical; this is bounded
linear preservation, not full-FCI inheritance. Docs source and strict build pass.
The unchanged canonical source guard fails `foreign matrix successor delta`,
as expected for a new unreviewed postimage. Full moving is not launched merely
to rediscover that known stop condition. Central owner must reconcile source
policy/postimages and select the stable admission gates. Canonical is unchanged.
The unchanged master #1072 still fails its pre-existing stale-inheritance check;
all243 dispositions remain unchanged. See the existing status/coverage records
for the decoded evidence hash, exact row receipts and owner handoff.

## Exclusions and next blocks

Pond/rain/irrigation/SSDI/macro, aquifer mutation, age, Soil-N/crop-N,
root salinity feedback, default bootstrap/multicolumn and portable restart stay
excluded. No whole master row is promoted. Existing master #1072 and the
NUT/SOL owner #1117 retain their wider authority and blockers. Next independent
SOL block is water-age amount/production on accepted carriers; next NUT block
is mineral NH4/NO3 inventory plus transport and whole-N restart before reactions.
