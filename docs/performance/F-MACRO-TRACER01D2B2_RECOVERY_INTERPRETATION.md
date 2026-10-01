# F-MACRO-TRACER01-D2B2 — recovery-observation interpretation and mass-envelope result

Date: 2026-10-01

Status: QUALIFIED_RECOVERY_CONSISTENCY_BOUND / EXACT_95_PERCENT_REPRODUCTION_NOT_REQUIRED / f_MB_NOT_IDENTIFIED

Canonical authority:

    integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

Historical exact-source authority:

    backup/ppa-before-reconcile-20260928
    integration/audits/PPA_WU05A1_SOURCE_CENSUS.json

## Purpose

Reconcile the reported approximately 95% Spechtacker bromide recovery with:

1. the D2A coupled tracer forward result;
2. the canonical/legacy macropore lower-boundary ownership;
3. the actual experimental observation procedure.

The key question is whether 5% unrecovered tracer must be interpreted as a
modeled hydrologic bottom outflow.

## Experimental observation semantics

The Weiherbach plot experiments did not measure a bromide breakthrough flux at
the lower boundary.

The experimental procedure was destructive profile sampling approximately one
day after irrigation:

    plot = 1.4 m x 1.4 m
    vertical profiles excavated after 1 day
    10 cm x 10 cm x 10 cm soil samples
    samples collected through the profile to approximately 1 m
    bromide content reconstructed from sampled soil

The later LAST publication likewise compares simulated and observed vertical
bromide mass profiles in 10-cm depth increments to 1 m.

The same publication explicitly notes for other Weiherbach experiments that
coarse sample-grid resolution is a plausible reason for incomplete tracer
recovery.

Therefore:

    reported recovery != measured lower-boundary breakthrough flux

and the unrecovered fraction may contain observation/sampling/analytical terms
in addition to any genuine below-profile transport.

## Exact SWAP 4.3.1 source finding

The byte-exact B1.11 A1 source census already states:

    macropore bottom = impermeable
    no seepage-face outflow
    no macropore bottom external flux in the source-traced standard path

This independently confirms the D2B1 canonical finding.

The absence of a standard macropore bottom flux is therefore inherited from the
reference SWAP physics, not introduced by the FMR migration.

## Correct interpretation of the 95% value

ALT53 already defined the recovery datum as a composite constraint and rejected:

    f_MB = 1 - recovery

D2B2 sharpens that further.

The approximately 5% unrecovered mass is an upper envelope on mass not found in
the sampled profile under the experiment/observation procedure.

It is not a requirement that the physical model generate exactly:

    5% bottom hydrologic loss.

A model with zero explicit macropore bottom loss is not falsified by 95%
experimental recovery as long as it does not predict a below-profile loss that
exceeds the unrecovered envelope and no claim is made that the model reproduces
the measurement-recovery process itself.

## D2A consistency

D2A with f_MB=0 has:

    modeled tracer ledger closure ~= 100%
    explicit MB bottom loss = 0
    Profile-1 R2 = 0.9427
    held-out Profile-2 R2 = 0.9774

The modeled below-profile loss:

    0%

is below the observed unrecovered envelope:

    approximately 5%.

Therefore the D2A physical tracer result is:

    CONSISTENT_WITH_RECOVERY_BOUND

but not:

    EXACT_95_PERCENT_RECOVERY_REPRODUCED.

## Consequence for f_MB

Because the experiment does not separately observe:

- MB bottom breakthrough;
- MB wall-retained tracer;
- observation/sampling loss;

the 95% recovery datum cannot identify f_MB.

Adding a bottom-outflow process solely to force modeled recovery from 100% to
95% would be over-interpretation of the observation and would violate the
frozen no-residual-balancing rule.

## Consequence for D2B1 falsification

D2B1 remains valid:

    standard FMR is not a complete MB bottom-export owner.

But that missing owner is no longer a blocker to the narrower empirical claim
that the D2A tracer simulation is compatible with the reported recovery.

It remains a blocker only for a future claim that seeks to partition the
unrecovered mass physically among:

    MB bottom export
    wall retention
    lateral loss
    sampling/analytical loss.

## Decision

    REPORTED_95_PERCENT = PROFILE_RECOVERY_OBSERVATION
    MEASURED_BOTTOM_BREAKTHROUGH = NO
    EXACT_5_PERCENT_MODELED_BOTTOM_LOSS_REQUIRED = NO
    D2A_BELOW_PROFILE_LOSS_WITHIN_RECOVERY_ENVELOPE = YES
    D2A_RECOVERY_CONSISTENCY = PASS
    EXACT_RECOVERY_PROCESS_REPRODUCTION = NOT_CLAIMED
    f_MB_FROM_RECOVERY = NOT_IDENTIFIED
    STANDARD_FMR_BOTTOM_ROUTE_FALSIFICATION = PRESERVED
    DISPERSION = NOT_AUTHORIZED
    NEW_RFM_PHYSICS = NONE

## Scientific closeout

The strongest justified Spechtacker claim is now:

    the coupled no-dispersion SWAP5-matrix + frozen-RFM-IC tracer model
    reproduces Profile 1 well, transfers to held-out Profile 2, and does not
    violate the independently reported total recovery bound.

The experiment does not support a stronger decomposition of the unrecovered
5% without additional breakthrough or observation-process data.
