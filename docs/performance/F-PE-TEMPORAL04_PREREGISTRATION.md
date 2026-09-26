# F-PE-TEMPORAL04 — dynamic temporal-policy qualification against refined oracle

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

Parent: `F-PE-BALTOL02` / PR #647

Parent head: `4e33e4b536551d16268445f0694deaf118995bc8`

## Trigger

BALTOL02 admits the dt-scaled Reference balance numerical floor in production and restores a convergent independent fixed-substep oracle for the difficult dynamic-history domain.

TEMPORAL03 had already shown that stationary temporal-certificate budgets do not transfer to dynamic origins and that predecessor history strongly controls the indicator scale.

## Purpose

Use the recovered independent oracle to evaluate dynamic-history temporal-certificate policies by physical error, mass and runtime rather than by completion alone.

Research-only. No temporal-policy production change in P0-P2.

## Candidate policy families

### A. Current fixed budget

Retain the current fixed temporal head budget used by the exact coupling fixture.

### B. Fixed enlarged budget

Use the smallest fixed budget needed to complete the previously characterized dynamic frontier for the tested corrector class.

### C. History-aware scaled budget

Construct a budget from physically available origin/history scales rather than corrector displacement alone.

Candidate scaling must be preregistered before evaluation and may use only quantities available at the captured exact origin, such as:

- predecessor right-derivative norm;
- requested window duration;
- current corrector displacement magnitude;
- fixed minimum/maximum caps.

Do not fit directly to the oracle endpoint error of the same evaluation cases.

## P0 — oracle error map

Use the recovered N=32 fixed-substep oracle, with N=64 only for points whose refinement diagnostics require it.

Qualification matrix:

- B01 wet;
- B01 mid;
- B12 wet;
- O05 wet;
- O14 wet;
- O14 mid;
- both +/-10% dynamic-history directions;
- signed corrector offsets +/-0.001 and +/-0.01 cm.

For each candidate policy record:

- transaction completion;
- accepted substeps/retries;
- terminal max |dh| versus oracle;
- terminal max |dtheta| versus oracle;
- terminal bottom-flux difference;
- integrated bottom-exchange difference;
- mass residual;
- runtime.

## P1 — bounded acceptance envelope

A policy may advance only if it has a preregistered physically acceptable error envelope across all admitted cases and does not merely improve completion.

## P2 — coupled-shape replay

Any surviving policy must be replayed through production-shaped repeated correctors / MODFLOW-facing coupling patterns before production admission.

## Stop conditions

Stop or split if:

- oracle refinement is not adequate for a case;
- history-aware scaling becomes case-fit rather than physics-derived;
- mass or state error grows materially;
- one policy only works by bypassing exact transaction authority.

## Production boundary

No temporal default, retry policy or surrogate is changed in this workunit.

Any production admission requires a separate workunit after oracle-qualified evidence.