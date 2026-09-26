# F-PE-BALTOL01 closeout — Reference Richards balance-tolerance qualification

Date: 2026-09-26

Status: `CLOSED_SCALED_NUMERICAL_FLOOR_QUALIFIED_NO_PRODUCTION_ADMISSION`

## Question

Can the Reference Richards balance convergence floor be made numerically robust without materially weakening the reference physical solution or mass authority?

## Answer

Yes, within the qualified difficult dynamic domain, when the balance-rate tolerance is bounded by an integrated numerical-resolution floor rather than by one fixed rate threshold.

Qualified candidate:

`tol_rate = max(1e-12 cm/day, 2.8e-16 cm / dt)`

applied identically to compartment and total balance convergence gates.

## Evidence

### P0 broad matrix

Across 240 difficult dynamic physical points:

- fixed 1e-12: 113/240 complete;
- fixed 2e-12: 156/240;
- fixed 5e-12: 209/240;
- fixed 1e-11: 236/240;
- fixed 1e-10: 240/240.

No looser arm loses a strict success, and overlapping terminal state/flux differences remain negligible.

### P1 integrated-depth scaling

The historically anchored DEPTH_2P8E16 arm completes 240/240, recovers all 127 strict failures and loses no strict successes.

Its rate tolerance varies with dt from 2.8e-12 to 4.48e-11 cm/day over the matrix, remaining substantially stricter than a blanket 1e-10 arm for most steps.

Maximum differences versus the strictest successful physical solution are approximately:

- |dh| <= 5.95e-13 cm;
- |dtheta| <= 1.67e-16;
- terminal-flux difference <= 8.88e-12 cm/day.

Mass accounting remains complete.

### P2/P2R refined oracle recovery

The previously blocked TEMPORAL03 certificate-free fixed-substep oracle now completes all 32 difficult dynamic points at N=8,16,32.

31/32 satisfy the original monotonicity gate immediately.

The single terminal-flux exception was refined to N=64 and contracts consistently across state, flux and integrated exchange.

Mass residuals remain at roundoff scale.

## Scientific interpretation

The earlier short-duration failure was not evidence of an inherent Richards instability.

It arose because a fixed residual-rate threshold of 1e-12 cm/day was pushed below the representable numerical balance floor as dt decreased.

The qualified scaling is consistent with earlier admitted PUB-P2E06/P2E07 authority: the limiting numerical resolution is better represented as an approximately fixed integrated water-depth scale than as a dt-independent residual rate.

## Decision

BALTOL01 closes qualification-only.

No production `src/**` change is admitted here.

No global default is changed.

No unrelated solver tolerance is relaxed.

## Required successor

Open a separate production admission workunit for the qualified Reference balance floor.

That admission line must:

- identify every production path that owns compartment/total balance tolerance;
- preserve strict 1e-12 behavior whenever it remains above the scaled numerical floor;
- implement only the minimum dt-scaled lower bound supported by the qualified evidence;
- rerun canonical Reference, groundwater-coupling, restart and mass-authority suites;
- re-run the TEMPORAL03 refined oracle and then resume temporal-policy qualification.
