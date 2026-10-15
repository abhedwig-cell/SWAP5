# MC-SOL01 nonlinear matrix successor

Status: qualified and preserved bounded successor; safe canonical admission pending.
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
The initial source guard rejected `foreign matrix successor delta`, correctly.
The subsequent regie review and exact guard/preservation reconciliation are
recorded below; the original rejection remains in immutable science evidence.
The unchanged master #1072 still fails its pre-existing stale-inheritance check;
all243 dispositions remain unchanged. See the existing status/coverage records
for the decoded evidence hash, exact row receipts and owner handoff.

## Regie source-policy review (2026-10-15)

User continuation authorizes the bounded admission review through the existing
central-regie route (protocol full-cycle rule8 and the trajectory3 precedent).
This review accepts an explicit SWAP5 numerical difference for the nonlinear
application: use the existing canonical partition operator, not the legacy
iterate/near-unity shortcuts. It changes neither the Freundlich law nor B1.11's
immutable archive. It does not claim an independently admitted new B1 snapshot.

For theta>0, rho*Kf>=0, Cref>0 and exponent>0, total storage is continuous and
strictly increasing from zero to infinity. Its inverse is therefore unique.
The existing bracketed production solve and independent quad Newton/closed
quadratic controls select that same storage relation. Literal transport order,
changing-water total mass, decay and all external receipts remain intact.
The executed two discrepancy witnesses establish why reproducing the historical
concentration shortcut would conflict with explicit dissolved/sorbed state.
Accept only the tested0.5..2 exponent application envelope; all prior exclusions
remain. This is a numerical/state-consistency acceptance, not new crop-N physics.

The reviewed production delta from ee2d8449 is exactly the constructor exponent
domain check plus comments. Existing process/solver/water/crop/state/codec sources,
callers, parameters and state schema are unchanged; the same real physical drivers
cover rejection/retry/continuation. All240 final science inputs and exact source
postimages remain bound to the existing1938-member capsule. An extension to the
existing preservation validator verifies that capsule, terminal native coverage,
raw commands/assertions, O0/O2 identity and the final driver/input binding.
Negative controls reject missing/failed cases, source drift, wrong flags/endpoints,
missing raw logs, foreign deltas and altered postimages. Original CO2 controls
and all original scientific preservation assertions remain required.

Stable preservation is now selected: one fresh local complete moving gate, resume
OFF, expected1825s based on the prior measured run. Compile/link/native breakdown
of that broad shell is UNKNOWN. This is the mandatory stable admission boundary,
not routine daily chemistry feedback. No highest low-air stress or duplicate
manual Actions dispatch is selected. Admission remains conditional on terminal
PASS, unchanged final science inputs, live overlap reconciliation and safe merge.

## Terminal preservation and canonical coexistence

Complete local moving preservation, resume OFF, passes exit0 in1829.803149s
on execution16e28f06, tree24f8af2c. All6218 tracked inputs remain unchanged.
Capsule `MC_SOL01_NONLINEAR_ADMISSION_20261015.tar.xz.b64`, decoded SHA256
`9400d206002dff638e04b05d2b7b8342447f928c74f6875db8d8cf0e11f2e7b1`,
retains full raw logs, controller, input inventory and actual execution bundle.
Fourteen frozen immutable authorities retain the unchanged workflow, exact
commit/tree objects and terminal run38631988831; no new hosted15-job run is claimed.

Canonical advanced concurrently to eb03024d, admitting mineral NH4/NO3 transport
via PR1231. All seven new production modules are distinct from the matrix owner;
all240 matrix and237 mineral science inputs remain byte-identical, with227 shared
hashes equal and401 existing module-provider ownerships unchanged. Neither driver
imports the other added production owner. Water, kernel, root/crop/WOFOST81,
existing interfaces, physical inputs, fixtures and build selectors stay identical.
The existing moving script is retained from the newer canonical unchanged.

Only admission guards need composition. They now require the exact union of
postimages, both independent terminal science capsules and all original CO2
assertions in situ. All53 original controls and3 extra peer negatives pass;
both small actual Fortran process closures run fresh. Ordinary owner validator
CLIs also pass without `-B` after preventing their own bytecode writes. Unit
control runners retain their declared `-B` isolation. No dirty-source check is
weakened. Raw failed CLI/control attempts remain retained.

The full nonlinear run above and the admitted mineral full moving1411.227377s
at6a1c3b7f cover the unchanged numerical/caller/state/compiler/input surfaces.
The exact scope/provider/fixture audit and fresh combined guard tests qualify
the new source-dispatch composition; this is not inheritance from imports alone.
No third complete run is selected for that guard-only composition. This admits
separate opt-in application routes, not simultaneous nitrogen-plus-solute state
or a new combined restart. Coexistence capsule decoded SHA256:
`44e43b53d2fe3ba60e9ef45b5e9960a79b6465a64d33137fa6a3c0b2ec7eb1d2`.

The provisional legacy-defect label is refined to ACCEPTED_SWAP5_DIFFERENCE:
historical stopping precision differs from the explicit SWAP5 phase-storage
contract; the witnesses do not establish a global legacy mass-conservation bug.
No new immutable B1 correction is asserted. Source line630 accepts frexp0..10;
only0.5..2 is covered here, so the whole sorption capability remains ACTIVE.

## Remaining scope

Pond/rain/irrigation/SSDI/macro, aquifer mutation, age, Soil-N/crop-N,
root salinity feedback, default bootstrap/multicolumn and portable restart stay
excluded. No whole master row is promoted. Existing master #1072 and the
NUT/SOL owner #1117 retain their wider authority and blockers. Next independent
SOL block is water-age amount/production on accepted carriers. PR1231 already
admits bounded mineral NH4/NO3 inventory, transport and joint restart. Next NUT
block is a bounded reaction such as nitrification with equal NH4 loss/NO3 gain
and whole-N accounting; organic/crop-N and source-policy decisions remain separate.
