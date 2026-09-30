# F-PE-NLGLOB14Z40 result — real reduced Heritage solve-service binding and focused A/B timing

Date: 2026-09-30

Status:

`QUALIFIED_Z40_REAL_REDUCED_RICHARDS_PHYSICAL_ONLY`

Qualification authority:

- workflow run: `36773430433`;
- job: `110085279075`;
- workflow conclusion: SUCCESS.
- run 1 (`36773059168`) failed before result exposure only because the test dependency scanner misread the variable `use_reduced` as a Fortran USE statement; the branch-local scanner word-boundary fix changed no scientific code.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Aggregate result

The first compiled full-vs-reduced Heritage HeadCalc A/B classifies:

`QUALIFIED_Z40_REAL_REDUCED_RICHARDS_PHYSICAL_ONLY`.

All four physical cases pass the frozen equivalence gates.

The geometric-mean reduced/full timing ratio is:

`0.97394`.

Thus the real reduced HeadCalc service is slightly faster on this tiny 16-node holdout, but not enough to satisfy the preregistered timing-gain threshold.

## Physical result

### O05_T13 — active n=13

- full and reduced nonlinear iterations: 2 / 2;
- full and reduced Jacobian builds: 2 / 2;
- max head difference: about `1.10e-41 cm`;
- theta difference: 0;
- top-flux difference: 0;
- ledger difference: 0;
- full/reduced tail start: 13 / 13.

Timing ratio:

`0.97027`.

### O05_T12 — active n=12

- nonlinear iterations: 2 / 2;
- Jacobian builds: 2 / 2;
- max head difference: about `1.26e-37 cm`;
- theta/top-flux/ledger differences: 0;
- full/reduced tail start: 12 / 12.

Timing ratio:

`0.95816`.

### O14_T13 — active n=13

- nonlinear iterations: 2 / 2;
- Jacobian builds: 2 / 2;
- max head difference: about `7.71e-22 cm`;
- theta/top-flux/ledger differences: 0;
- full/reduced tail start: 13 / 13.

Timing ratio:

`0.96479`.

### B12_T13 — active n=13

- nonlinear iterations: 2 / 2;
- Jacobian builds: 2 / 2;
- max head difference: about `1.85e-45 cm`;
- theta/top-flux/ledger differences: 0;
- full/reduced tail start: 13 / 13.

Timing ratio:

`1.00314`.

## Architectural result

Z40 confirms that the existing Heritage/reference HeadCalc service can genuinely execute at a reduced active dimension when:

- explicit parameter geometry carries reduced `active_nodes`;
- constitutive provider state is shape-consistent at n;
- source/sink provider state is shape-consistent at n.

No new nonlinear solver stack is required.

The same typed solver service is used for full and reduced routes.

The reduced candidate is reconstructed to a full 16-node candidate through the qualified manager seam.

## Interpretation

This is the strongest implementation result in the moving-interface line so far.

The physical equivalence problem is solved for the focused compiled holdout.

The current timing signal is directionally favorable but small because:

- the full test profile contains only 16 nodes;
- the reduced solve removes only 3–4 nodes;
- both full and reduced routes require the same 2 nonlinear iterations;
- fixed solver/provider overhead remains substantial relative to this small dimension change.

Therefore the next performance question is not whether reduced HeadCalc works. It does.

The next question is how the gain scales with:

- total profile node count;
- fraction of the profile removed from the nonlinear solve;
- active dimension.

## Qualified claim boundary

Qualified:

- actual Heritage/reference solver works at n=12/13 through explicit geometry and reduced provider views;
- full/reduced candidates are physically equivalent on all four frozen cases;
- manager publication remains full-shaped;
- same nonlinear iteration/Jacobian counts;
- focused 16-node timing is modestly favorable on average.

Not qualified:

- >=5% solve-service speedup on the 16-node holdout;
- scaling to larger/realistic SWAP discretizations;
- trajectory-level production timing;
- production admission.

## Consequence

Do not reopen moving-interface physics or provider-binding architecture.

Open a small active-dimension/profile-size scaling benchmark using the same real reduced HeadCalc route.

The scaling benchmark should establish whether the reduced solve becomes materially faster when the nonlinear tail reduction is larger and/or the full profile contains more nodes.

## Production boundary

Research binding only.

`LEGACY_NUMERICS` remains production default.
