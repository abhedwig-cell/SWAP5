# F-MACRO-ALT34 — retained SWAP5 fixture to full conservative RFM routing

Date: 2026-10-01

Status: QUALIFIED_END_TO_END_RESEARCH_COMPOSITION / CONSERVATION_PASS / ABSOLUTE_ACTIVATION_UNCALIBRATED

Baseline: integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b

## Purpose

Compose the retained FKT22 SWAP5 default-MvG hydraulic fixture through the full reduced RFM chain without adding new parameters or physics.

## Frozen chain

    retained SWAP5 top state h=-75 cm
      -> K_surface and S_surface
      -> dynamic activation with sigma_B=0.65
      -> MB/IC split with f_MB=0.25
      -> one-shape connectivity C(z)=1-x^p with p=0.66
      -> endpoint recruitment
      -> conservative water and unit-tracer routing

Z_AH=25 cm and Z_IC=85 cm are kept fixed for this composition screen.

## Hydraulic anchor

Using the same retained constitutive fixture as ALT33:

    K_surface ~ 0.16264 cm/day
    S_surface ~ 2.92460

with the 128-panel direct sorptivity oracle.

## Results for equal 40 mm input

### 20 mm/h

    preferential input      ~34.74 mm
    preferential fraction   ~0.869
    MB bottom receipt        ~8.68 mm
    IC deposition           ~26.06 mm
    mean IC endpoint         ~45.2 cm
    max recruited endpoint  ~79 cm
    water residual          ~-2.9e-13 mm
    tracer residual         ~-2.9e-13

### 40 mm/h

    preferential input      ~36.31 mm
    preferential fraction   ~0.908
    MB bottom receipt        ~9.08 mm
    IC deposition           ~27.24 mm
    mean IC endpoint         ~46.4 cm
    max recruited endpoint  ~81 cm
    water residual          ~9.3e-13 mm
    tracer residual         ~9.3e-13

### 60 mm/h

    preferential input      ~37.08 mm
    preferential fraction   ~0.927
    MB bottom receipt        ~9.27 mm
    IC deposition           ~27.81 mm
    mean IC endpoint         ~46.9 cm
    max recruited endpoint  ~82 cm
    water/tracer residual    floating-point scale

## Main engineering result

The full composition is dynamically well-defined and conservative when anchored in an existing SWAP5 hydraulic fixture.

The route now spans:

    SWAP5 constitutive state
    surface sorptivity
    activation
    continuous/deep MB split
    terminating IC recruitment
    fast storage/transit
    water receipt
    conservative tracer receipt

without event-specific geometry or hidden hydraulic surrogates.

## Main scientific result — strong pressure on sigma_B/default activation

The absolute preferential fractions are very high:

    ~87% at 20 mm/h
    ~91% at 40 mm/h
    ~93% at 60 mm/h

for this retained h=-75 cm state.

This is not a routing or mass-balance failure. It is a direct consequence of the current activation hypothesis and provisional sigma_B=0.65 interacting with the actual SWAP5 constitutive state.

Therefore the line now has a clear empirical calibration/transferability target:

    sigma_B=0.65 must not be treated as a generic default.

The parameter was useful as a structural research value, but real-data qualification must determine whether a profile-specific sigma_B can transfer across events.

## Why this is useful

Until ALT34, high preferential fractions could be dismissed as artifacts of generic hydraulic examples. That is no longer true: the effect survives composition with a retained SWAP5 default-MvG fixture.

This sharply increases the value of the planned empirical test.

## Decision

END_TO_END_RETAINED_FIXTURE_COMPOSITION = PASS
WATER_CONSERVATION = PASS
CONSERVATIVE_TRACER = PASS
ONE_SHAPE_ENDPOINT_ROUTING = PASS
SIGMA_B_0P65_AS_GENERIC_DEFAULT = NOT SUPPORTED
ABSOLUTE_PREFERENTIAL_AMOUNT = EMPIRICAL_QUALIFICATION_REQUIRED

## Next

ALT35 should focus specifically on activation transferability rather than alter routing.

Required experiment:

1. obtain event-level preferential occurrence/amount observations for one structural profile;
2. estimate one sigma_B from a calibration subset only;
3. hold sigma_B fixed;
4. test weak/intense, short/long and antecedent-state held-out events;
5. reject the fixed-sigma_B hypothesis if systematic intensity or antecedent-state bias remains.

If event-level payload access remains blocked, the correct research status is an explicit empirical blocker. Do not tune sigma_B against the retained SWAP fixture merely to obtain visually plausible fractions.
