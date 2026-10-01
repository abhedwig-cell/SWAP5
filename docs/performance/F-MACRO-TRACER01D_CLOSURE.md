# F-MACRO-TRACER01-D — closure

Date: 2026-10-01

Status: CLOSED_ON_QUALIFIED_FORWARD_HELDOUT_AND_MB_WALL_COMPOSITION_BLOCKER

Branch: `research/f-macro-tracer01-reference-kernel`

Canonical SWAP5 authority:

    integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

## Qualified sequence

### D1 — software composition

The disposable conservative tracer kernel is qualified against real accepted
SWAP5 Richards solves through the accepted-state flux observer.

The 120/60/30-s refinement gate passed with floating-point-scale tracer
closure and convergent profile differences:

    L1_120_60 = 0.0015162192486311466
    L1_60_30  = 0.0007659631795578947

No production source code was changed.

### D1S — publication initial-state sensitivity

Primary sources do not provide a full observed Spechtacker 0-1 m pre-irrigation
theta(z) profile. The available initial-state evidence represents the upper
15 cm macrostate.

A preregistered five-member publication-faithful deep-state envelope was
therefore executed without claiming exact replay.

Across theta(1 m)=0.234...0.314:

    tracer centroid = 0.094342...0.095179 m
    max normalized L1 shift to central = 0.003615

while the observed Spechtacker Profile-1 centroid is about 0.176 m.

Thus the unknown deep initial state does not explain the observed depth signal
within the preregistered envelope.

### D2A — coupled bromide forward comparison

D2A then executed the process-coupled subset:

    publication forcing
      -> RFM activation from current accepted SWAP5 state
      -> q_matrix -> SWAP5 Richards -> matrix tracer
      -> q_preferential -> frozen IC endpoint routing
      -> observed 10-cm bromide bins

with:

    p = 0.249 frozen
    f_MB = 0 for this identifiability stage only

The preregistered sigma_B grid selected 0.10 by Profile-1 SSE.

Profile 1:

    R2 = 0.9427036980
    RMSE = 0.0386303959

Profile 2, held out with no refit:

    R2 = 0.9774136087
    RMSE = 0.0264813070

The full coupled tracer/source ledger closes at floating-point scale.

Therefore:

    BROMIDE_FORWARD_COMPARISON = QUALIFIED_FOR_D2A_SUBSET
    PROFILE2_HELDOUT_VALIDATION = PASS

The selected sigma_B lies exactly on the lower preregistered grid boundary.
Its absolute magnitude is therefore not identified by this work unit.

### Recovery boundary

With f_MB=0, D2A predicts essentially 100% recovery.

The publication reports approximately 95%.

That difference cannot be converted directly to f_MB. Under ALT53/ALT55,
recovery constrains a composite of preferential entry, f_MB, MB wall retention,
MB survival and bottom/deep receipt.

## D2B blocker

The repository has qualified wall-exchange theory and parameter roles, but no
source-bound executable Spechtacker MB tracer owner that publishes:

    MB wall-retained tracer by 10-cm depth bin
    MB bottom/deep tracer mass
    exact MB tracer closure

ALT34 is a generic retained-fixture MB routing screen, not that owner.

Creating the missing travel/contact and depth-resolved tracer-routing semantics
solely to fit the 95% recovery would introduce new RFM physics and would make
f_MB a residual mass balancer. Both are explicitly forbidden in this line.

Therefore:

    FULL_95_PERCENT_RECOVERY_FORWARD_VALIDATION = BLOCKED
    BLOCKER = SOURCE_BOUND_MB_WALL_TRACER_OWNER_MISSING

## Dispersion

The no-dispersion chain has passed:

- matrix software composition;
- timestep refinement;
- publication initial-state sensitivity;
- Profile-1 coupled forward comparison;
- held-out Profile-2 validation.

No qualified no-dispersion failure exists.

Therefore:

    DISPERSION_EXTENSION = NOT_AUTHORIZED

## Final state

    D1_MATRIX_COMPOSITION = QUALIFIED
    D1_TIMESTEP_REFINEMENT = PASS
    D1S_INITIAL_STATE_SENSITIVITY = PASS
    EXACT_PUBLICATION_REPLAY = NOT_CLAIMED
    D2A_BROMIDE_FORWARD_COMPARISON = QUALIFIED
    D2A_PROFILE2_HELDOUT = PASS
    sigma_B_ABSOLUTE_IDENTIFICATION = NOT_ESTABLISHED
    D2B_ABSOLUTE_RECOVERY = BLOCKED
    D2B_BLOCKER = MB_WALL_TRACER_OWNER_MISSING
    NEW_RFM_PHYSICS = NONE
    PRODUCTION_CODE_CHANGE = NONE
    STOP_RULE = TRUE_COMPOSITION_BLOCKER

## D2B1 source audit and route falsification

A direct audit of the canonically admitted standard FMR macropore runtime
resolved part of the D2B blocker.

The runtime already publishes source-owned wall-water exchange by domain and
compartment and a balance-reconstructed vertical internal macropore flux.
Those are suitable hydrologic observables for a disposable conservative tracer
observer.

However, the admitted standard candidate balance is:

    storage change
      = accepted top input
      - wall exchange to matrix
      - rapid external drainage

There is no independent continuous macropore lower-boundary export term.

Because the vertical-flux reconstruction uses the same terms, summing it over
the active domain gives an algebraic lower-face flux of zero up to roundoff.

Therefore the route:

    canonical standard FMR
      -> reconstructed lower macropore face
      -> Spechtacker below-1-m bromide loss

is explicitly falsified.

A10 rapid drainage cannot be substituted because it is a separately owned
drain-level/resistance process, not vertical breakthrough below the sampled
profile.

The residual D2B need is now narrower than before:

    wall exchange owner = available
    internal vertical transfer observer = available
    independent MB bottom/deep export owner = absent

This is a source-ownership blocker, not a tracer-conservation blocker.

## Updated stop condition

    D2A depth-profile forward validation = qualified
    Profile-2 held-out validation = pass
    canonical FMR wall-exchange reuse = source-compatible
    canonical standard FMR as complete MB bottom owner = falsified
    rapid drain as MB bottom receipt = rejected
    full 95-percent recovery validation = blocked on real MB lower-boundary owner
    new RFM physics = none

This work unit closes at the requested valid stop condition: an explicitly
falsified route with the remaining dependency isolated.
