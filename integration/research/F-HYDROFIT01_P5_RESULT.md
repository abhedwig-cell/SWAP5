# F-HYDROFIT01 P5 result

Canonical authority remained `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`.

## Negative result 1

Run `36403865485` at `fac79f97d667ab5642d59292f8834cc3f231ba49`: FAILURE.

Initial candidate generation respected independent box bounds but generated physically invalid combinations with `theta_r >= theta_s`. This demonstrated that optimizer box bounds are insufficient to define the physical ensemble domain.

Correction: reject coupled-unphysical candidates before objective evaluation. The objective envelope was not changed.

## Negative result 2

Run `36403958154` at `f1b2a16ee7306eeeb50d5d21156c886aa3734a4d`: FAILURE.

After physical filtering, the primary envelope retained only the optimum. Diagnosis: the nominally local sampler multiplied SVD-direction perturbations by the global parameter box span. The very broad generic bounds, especially for Ks, made these proposals nonlocal in objective space.

Again, the preregistered envelope was not widened.

## Qualified correction

Local proposals now use the local quadratic geometry

`J(p + dx) ~= J* + ||Jac dx||^2`.

Random directions are drawn in right-singular-vector coordinates and scaled to a deterministic target delta-J. Weak singular directions therefore receive larger parameter displacement while strongly informed directions remain close to the optimum.

Run `36404038063` at `99401de919d9c1edca7c0f4cb6b7f158454435e6`: SUCCESS.

The test suite establishes:

- deterministic seeded candidate generation;
- nested tight, primary and wide objective envelopes;
- more than one retained candidate in the primary envelope for the deliberately information-limited case;
- nontrivial parameter spread among primary-envelope members;
- direct objective re-evaluation for retained candidates;
- preservation of all P2-P4 gates.

## Interpretation

P5 now has a qualified mechanism for exploring objective-near-equivalent parameter sets. The mechanism is local-geometry informed plus broader bounded exploration; it is not a posterior sampler.

The two failed runs are retained because they expose important implementation constraints: physical coupled bounds and objective-space scaling cannot be replaced by generic box sampling.

## Remaining P5 work

The current executable gate establishes parameter-space spread. Before P6, add explicit theta(h) and K(h) envelope summaries on a fixed head grid and select diverse primary-envelope representatives by function-space distance.

Only those functionally diverse representatives should be sent to the SWAP numerical probe.
