# F-MACRO-TRACER01-D2B — MB recovery-composition blocker

Date: 2026-10-01

Status: TRUE_COMPOSITION_BLOCKER / MB_WALL_TRACER_OWNER_MISSING

## Entry condition

D2A has qualified the coupled:

    activation + SWAP5 matrix hydrology + matrix tracer + IC endpoint tracer

subset against Spechtacker Profile 1 and held-out Profile 2.

The remaining empirical constraint is absolute recovery:

    published recovery ~= 95%

while D2A with f_MB=0 gives essentially 100% retained/recovered tracer.

## Required D2B contract

ALT55 requires full explicit closure:

    applied tracer
      = matrix retained
      + IC retained
      + MB wall retained
      + MB bottom

The first two owners now exist and are executable for this case.

D2B still requires an executable owner that publishes, in the same 10-cm
sampling bins:

    MB wall-retained tracer profile

and separately:

    MB bottom/deep tracer receipt.

## Repository audit

The current RFM research line contains the wall-exchange theory and parameter
reduction:

    q_philip ~ chi_wall * (4/ell_ex) * S_wall * Delta sqrt(t)
    q_darcy  ~ f_shape * 8 K |Delta h| / ell_ex^2 * Delta t
    q_wall   = max(q_philip, q_darcy)

ALT29 also defines a route to derive ell_ex from measured structural geometry.

These authorities establish exchange-rate roles and parameter ownership.

They do not provide a source-bound Spechtacker conservative-tracer runtime that
determines, along an MB pathway:

- depth-resolved contact history;
- moving MB tracer mass by depth;
- depth-resolved lateral water/tracer exchange;
- residence/travel time to the 1-m sampling boundary;
- wall-retained tracer publication in the observed 10-cm bins;
- bottom/deep tracer survival.

ALT34 is not that owner. It is a retained-fixture composition screen with a
generic MB transit/bottom route and does not publish a source-bound
Spechtacker MB wall-retained tracer profile.

## Why f_MB cannot close the gap alone

For the D2A selected activation member:

    F_pref ~= 0.62886

and observed missing total tracer is approximately:

    0.05

The recovery datum therefore constrains a composite quantity resembling:

    F_pref * f_MB * survival_to_below_sampled_profile

after accounting for wall retention and other explicitly owned losses.

It does not identify f_MB by itself.

Setting f_MB so that the ledger lands on 95% recovery would violate the frozen
ALT53/ALT55 rule that f_MB is not a residual mass balancer.

## Why an immediate implementation is not authorized

Completing the missing runtime would require freezing new MB travel/contact and
depth-resolved tracer-exchange semantics that are not currently owned by an
existing executable research contract.

Those choices would materially affect f_MB interpretation and the retained
bromide profile.

Introducing them merely to make recovery fit would be new RFM physics, which is
outside TRACER01-D authorization.

## Decision

    MATRIX_TRACER_OWNER = QUALIFIED
    IC_ENDPOINT_TRACER_OWNER = QUALIFIED
    HELDOUT_PROFILE2 = PASS
    MB_WALL_RATE_THEORY = AVAILABLE
    SOURCE_BOUND_MB_TRACER_RUNTIME = ABSENT
    MB_WALL_RETAINED_PROFILE_OWNER = ABSENT
    MB_BOTTOM_SURVIVAL_OWNER = ABSENT
    f_MB_RESIDUAL_BALANCING = FORBIDDEN
    FULL_95_PERCENT_RECOVERY_FORWARD_VALIDATION = BLOCKED
    STOP_RULE = TRUE_COMPOSITION_BLOCKER

## Resume condition

Resume D2B only when a frozen, independently justified MB tracer-routing owner
exists that can publish:

1. wall-retained tracer by depth;
2. bottom/deep tracer mass;
3. exact MB tracer closure;

without fitting those missing process semantics to the 95% recovery target.

At that point f_MB may be tested jointly against depth profile and absolute
recovery without changing p or using recovery as a residual balancing device.
