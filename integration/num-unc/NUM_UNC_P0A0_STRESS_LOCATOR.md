# NUM-UNC P0A0 preregistration: drought-stress timing locator

Date: 2026-09-19
Timing: before any P0A numerical execution
Baseline: integration/f-ci-canonical@187e30153c890151768e929170d14bb22af1d86d

## Purpose

P0A0 locates, with N0 only, a controlled drought-stress transition around a fixed rescue event. It is the third independent mechanism screen after P0C and P0B0.

P0A0 cannot support a NUM-UNC mechanism claim. It only freezes physical cases before an N1 comparison.

## Process authority

Use the current canonical evaluate_macro_feddes_drought_uptake process and current Reference Richards root-sink provider.

Feddes parameters are bound by NUM_UNC_P0A_PARAMETER_AUTHORITY.md: hlim3h=-325 cm, hlim3l=-600 cm, hlim4=-8000 cm, adcrh=0.5 cm/day, adcrl=0.1 cm/day.

Potential transpiration is fixed at 0.1806735915459957 cm/day. At this forcing the critical drought head is computed by the current process formula. No hlim3 value is hard-coded separately.

## Controlled physical case

- material: B01;
- 16 cell-centred cells x 10 cm, total depth 160 cm;
- rooted nodes: first 6 cells, root depth 60 cm;
- cumulative root fraction: uniform over the six rooted cells;
- root development: off;
- oxygen, salinity, frost and compensation: outside this controlled mechanism;
- drainage and subsurface irrigation: off;
- lower boundary: prescribed zero flux;
- top boundary: fixed explicit flux.

The uniform six-cell root distribution is a research control, not a claim that the Hupsel crop had this exact profile.

## Temporal forcing

N0 step = 0.0064 day. Total horizon = 192 blocks = 1.2288 day.

Rescue starts at block 65, after 64 complete drydown blocks, so t_rescue = 0.4096 day.

Top flux is zero in blocks 1..64, +Tp in blocks 65..80, and zero in blocks 81..192. The rescue pulse therefore supplies the same rate as potential transpiration for 16 blocks. This is a controlled perturbation, not irrigation calibration.

## Stress event

At the start of every step, root uptake is evaluated from the currently accepted hydraulic state. The resulting lagged root-sink vector is then held fixed during that Reference Richards step, matching the admitted SWKIMPL=0 explicit root-sink contract.

Define a drought-stress event when Ta/Tp < 0.999999999999 at an accepted step origin. The 1e-12 relative deadband prevents floating representation noise around alpha=1 from defining the event.

Primary locator class is STRESS_BEFORE_RESCUE if the first event occurs at a step origin strictly before t_rescue, and NOT_BEFORE_RESCUE otherwise. The event class is based on process output before each solve, not on a post-hoc head threshold.

## Continuation coordinate

The current Feddes parameter set and Tp determine a critical pressure head hcrit and corresponding B01 effective saturation Secrit.

P0A0 searches only the prospectively frozen offsets above Secrit: delta_Se = [0, 0.0025, 0.005, 0.010, 0.020]. Values outside (0,1) are inadmissible.

The first adjacent pair changing from STRESS_BEFORE_RESCUE to NOT_BEFORE_RESCUE defines the bracket. No search-envelope expansion is allowed.

If a bracket exists, exactly 12 N0 bisection iterations are executed.

Freeze: A- = Se* - 0.0025, A0 = Se*, A+ = Se* + 0.0025. A valid freeze requires A- = STRESS_BEFORE_RESCUE and A+ = NOT_BEFORE_RESCUE. These offsets may not be widened after observing the result.

## Study admissibility

Every solve must report Reference SW_SOLVE_CONVERGED, retain dt=0.0064 day, use no internal retry or alternative linear solver, provide finite states, retain water content inside the B01 constitutive envelope, and provide a finite typed integrated mass residual <= 1e-12 cm in magnitude.

The root process must return ROOT_UPTAKE_OK and finite nonnegative sink components. A failed case is INADMISSIBLE, not a scientific transition.

## Data firewall

P0A0 contains no N1 execution path. The A-/A0/A+ effective saturations and N0 classes must be persisted before A1 is preregistered. No case relocation is permitted after N1 exists.
