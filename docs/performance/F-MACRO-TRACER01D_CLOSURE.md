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

This work unit closes at the requested valid stop condition.
