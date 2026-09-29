# F-PE-NLGLOB05 result — strict floor-certificate discrimination

Date: 2026-09-29

Status:

`NLGLOB05_CERTIFICATE_NONSPECIFIC`

Canonical base:

`integration/f-ci-canonical@01adcb51992615e7a09016f1ce63a244c40acf3c`

Qualification authority:

- workflow run: `36540909373`;
- job: `109315813406`;
- conclusion: SUCCESS.

## Candidate

This result evaluates the strict C0 certificate preregistered before NLGLOB05A result exposure.

In addition to balance/storage-floor evidence, C0 requires:

- normalized Newton correction `z_h_inf <= 1e-8`;
- existing head convergence `M_H <= 1`;
- no >10% improvement among the backtracking factors already tested in that Newton iteration;
- finite state and route consistency.

No solver decision was changed.

## Coverage

PASS.

- cases: `96`;
- audited iterations: `768`;
- primary poor-model near-floor iterations: `333`;
- diagnostic coverage: `1.0`;
- process failures: `0`.

## Positive population

Strict C0 certifies:

`215 / 333`

primary iterations.

Certified primary fraction:

`0.64565`.

Coverage is broad:

- TG certified: `112`;
- KLAG certified: `103`;
- routes: FLUX, HEAD, RUNOFF;
- materials: B01, B12, O05, O14.

Every route-mode family certifies at least 60% of its primary population:

- FLUX / KLAG: about 60.6%;
- FLUX / TG: about 61.8%;
- HEAD / KLAG: about 70.6%;
- HEAD / TG: about 64.7%;
- RUNOFF / KLAG: 60.0%;
- RUNOFF / TG: about 71.2%.

Thus the candidate is not too narrow.

## Hard negative controls

All hard unresolved controls are rejected perfectly:

- above-floor N2: false-positive rate `0`;
- storage-floor-absent N3: false-positive rate `0`;
- head-unresolved N4: false-positive rate `0`;
- nonfinite / route-invalid N5: false-positive rate `0`.

## Decisive nonspecificity

The preregistered adequate-model control N1 contains:

`433`

iterations with selected model-quality rho >= 0.25.

Strict C0 certifies:

`27.94%`

of this control population.

The frozen maximum was:

`5%`.

Therefore strict C0 remains substantially nonspecific.

The additional within-iteration evidence:

- tiny Newton correction; and
- lack of material improvement among already tested backtracking factors

does not uniquely identify terminal numerical exhaustion.

## Frozen classification

`NLGLOB05_CERTIFICATE_NONSPECIFIC`.

The discriminator does not qualify.

No acceptance replay is authorized.

## Combined NLGLOB05 interpretation

NLGLOB05A showed that the local floor/head/pond snapshot appears too early in the Newton trajectory.

Strict NLGLOB05 C0 shows that adding within-iteration correction collapse and backtracking stagnation reduces but does not remove nonspecificity.

The missing discriminator is therefore not simply another scalar threshold on the current Newton iteration.

The remaining hypothesis must be **cross-iteration persistence / trajectory structure**.

Examples of admissible observational evidence for a successor include:

- consecutive iterations remaining in the same balance/storage floor neighborhood;
- sustained collapse of head updates;
- repeated lack of material merit improvement;
- repeated poor or changing model-quality rho;
- stagnation slope of `r_bal`, `z_h`, or merit across consecutive accepted Newton origins.

These must be preregistered before outcome exposure.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No tolerance, mass, MAXIT, backtracking, timestep, K-staging or route/event change.

`LEGACY_NUMERICS` remains production default.
