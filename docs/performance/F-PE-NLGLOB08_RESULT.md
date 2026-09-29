# F-PE-NLGLOB08 result — post-stationarity physical tail-drift attribution

Date: 2026-09-29

Status:

`NLGLOB08_POST_STATIONARITY_TAIL_PHYSICALLY_INERT`

Canonical base:

`integration/f-ci-canonical@a82721f5ebece9376f83ab9b0fe5df26e42a36f2`

Qualification authority:

- workflow run: `36548799864`;
- job: `109341595842`;
- conclusion: SUCCESS.

## Frozen question

After an NLGLOB07 S0-certified point, does any later accepted Newton origin change the physical moisture state by more than the unchanged `5e-8 cm` physical accepted-interval mass significance scale?

No solver behavior was changed.

## Coverage

PASS.

- bank cases: 96;
- audited Newton iterations: 768;
- NLGLOB07 S0-certified points: 302;
- early S0-certified points: 110;
- terminal S0-certified points: 96;
- diagnostic coverage: 1.0;
- process failures: 0.

## Main result

All S0-certified points are physically tail-inert:

- all-S0 inert fraction: `1.0`;
- early-S0 inert fraction: `1.0`.

The positive direction spans:

- TG and KLAG;
- FLUX, HEAD and RUNOFF;
- B01, B12, O05 and O14.

For the 110 early S0 points:

- median `TAIL_MAX = 0.0 cm`;
- 95th percentile `TAIL_MAX ≈ 4.44e-15 cm`;
- maximum `TAIL_MAX ≈ 7.77e-15 cm`.

The maximum observed post-stationarity physical moisture movement is therefore more than six orders of magnitude below the unchanged `5e-8 cm` physical mass gate.

No route/nonfinite pathological tail was observed.

## Comparator

Among 274 non-S0 early points, about 7.30% show later meaningful physical motion above `5e-8 cm`.

This confirms that the tail-drift metric is not trivially zero for all early trajectory states.

## Frozen classification

`NLGLOB08_POST_STATIONARITY_TAIL_PHYSICALLY_INERT`.

All frozen gates pass.

## Scientific interpretation

NLGLOB07's early S0 triggers are temporally early but physically inert on the frozen dynamic-top bank.

Once S0 is reached, subsequent Newton iterations do not change the accepted moisture state by physically meaningful water depth.

This resolves the main safety objection raised by NLGLOB05-07:

- the arithmetic storage/balance floor is real;
- the S0 state-stationarity signature can occur before the final canonical Newton iteration;
- but those additional iterations are physically futile on the frozen bank.

Iteration position is therefore not an appropriate negative control for S0 in this scope.

## Consequence

A separately preregistered test-only replay is now authorized.

The replay may terminate an endpoint solve when the unchanged S0 condition is reached, provided:

- current head and ponding guards pass;
- route and finite-state guards pass;
- unchanged physical accepted-interval mass closure passes;
- cumulative physical mass closure passes;
- accepted-state comparison remains within the later canonical endpoint trajectory envelope;
- acceptance is explicitly diagnosed as numerical-floor/state-stationarity termination.

No production convergence change is admitted by NLGLOB08 itself.

## Preserved authority

NLGLOB05, NLGLOB06 and NLGLOB07 remain valid negative discriminator results.

NLGLOB08 does not rewrite them. It establishes that the early-control assumption used there was conservative but not physically discriminating for the frozen bank.

BALTOL02 and physical mass authority remain unchanged.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No tolerance, mass, MAXIT, backtracking, timestep, K-staging or route/event change.

`LEGACY_NUMERICS` remains production default.
