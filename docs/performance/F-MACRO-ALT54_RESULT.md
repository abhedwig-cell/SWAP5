# F-MACRO-ALT54 — empirical parameter-identifiability synthesis

Date: 2026-10-01

Status: QUALIFIED_EMPIRICAL_SYNTHESIS / p_PROMOTED / sigma_B_AND_f_MB_PARTIALLY_BLOCKED

## Purpose

Consolidate the empirical evidence accumulated from NEON, HILLSCAPE, GFZ/Hartmann, Weiherbach/Spechtacker, Colpach and the North-China dual-infiltration study into one parameter-specific identifiability verdict for RFM-RC1.

No RFM equation or parameter contract is changed.

## sigma_B — surface activation heterogeneity

### What is supported

NEON v1.1 gives a strong monotone event-ordering result:

    low RFM activation score  -> low observed PF frequency
    high RFM activation score -> high observed PF frequency

with AUC ~0.666 on 34,355 hydraulically valid events.

This supports the activation law as an informative event-ordering mechanism.

### What is not identified

Binary PF occurrence is nearly invariant in rank over sigma_B from approximately 0.3 to 1.3.

Therefore binary PF labels do not identify the absolute sigma_B scale.

### Quantitative direct-partition search

The North-China dual-infiltration study publishes replicate-level:

    SIR = steady total infiltration rate
    MIR = matrix infiltration rate
    PFIR = SIR - MIR
    PFIR / SIR

which is a direct quantitative preferential-flow fraction.

However the experiment is performed under double-ring / constant-head steady infiltration.

That belongs to the ponded/head-controlled regime.

RFM-RC1 sigma_B governs:

    unponded/source-controlled activation.

Therefore using North-China PFIR/SIR to calibrate sigma_B would mix two different boundary regimes and is rejected.

### sigma_B verdict

    activation ordering = empirically supported
    generic sigma_B=0.65 = not supported
    absolute sigma_B magnitude = not identified
    ponded PFIR datasets = not valid sigma_B calibration targets

The clean sigma_B target remains:

    quantitative unponded matrix-versus-preferential entry fraction
    under controlled source forcing.

## p — terminating pathway depth shape

### Dye evidence

GFZ trinary dye morphology does not admit a general direct mapping:

    stained_fraction(z) proportional to 1 - x^p.

That observation operator is rejected.

### Conservative tracer evidence

Numerical bromide depth profiles from the open echoRD testcases provide a direct conservative-tracer mass observation.

Spechtacker Profile 1:

    p_eff ~0.249
    R2 ~0.985

Spechtacker Profile 2:

    p_eff ~0.219
    R2 ~0.981

Using Profile 1 p without refitting:

    Profile 2 held-out R2 ~0.975.

Independent Colpach:

    p_eff ~0.385
    R2 ~0.902.

### p verdict

The one-shape endpoint-mass law is held-out validated.

p is now the best empirically identified free parameter in RFM-RC1.

The remaining distinction is:

    p_eff from retained tracer depth profile

versus:

    structural p in the full forward model.

A full tracer-routing simulation is required before assuming exact equality, but the leading one-shape form is strongly supported.

## f_MB — continuous/deep preferential pathway fraction

### Structural/deep evidence

Weiherbach source studies report:

Spechtacker:

    bromide recovery = 95%

Site 33:

    bromide recovery = 96%.

Therefore total tracer leaving the sampled/recovered system is tightly bounded at approximately 4-5%.

### Why recovery does not directly give f_MB

f_MB multiplies preferential input, not total source.

In addition, MB tracer can exchange into matrix before leaving below the sampled profile.

The observable deep-loss product contains:

    F_pref
    x f_MB
    x MB survival after wall exchange
    x bottom/deep exit fraction.

Thus:

    f_MB = 1 - recovery

is rejected.

### HILLSCAPE evidence

The mass-based same-event subsurface-flow receipt:

    (Q_SSF / P) * f_eventwater

ranges from ~0.18% to ~31.6%.

This is a real quantitative fast-routing receipt.

But it is a lateral trench receipt after storage and hillslope routing, not a direct vertical MB fraction.

### f_MB verdict

    direct f_MB = not identified
    deep-loss / fast-routing composite constraints = available
    full forward tracer + routing model required

## chi_wall — optional wall/contact correction

No current dataset uniquely identifies chi_wall independently of:

    exchange length
    pathway geometry
    matrix hydraulics
    contact history.

ALT29 already derives exchange length from structure where possible.

Therefore chi_wall remains:

    optional
    evidence-required
    not a default free calibration parameter.

## Current empirical strength ordering

1. p:
   
       strongest empirical support
       held-out conservative-tracer depth validation

2. sigma_B:
   
       activation ordering supported
       magnitude non-identifiable

3. f_MB:
   
       constrained only through composite mass/deep-routing receipts

4. chi_wall:
   
       not independently identified

## Research implication

The RFM-RC1 parameter burden remains justified:

    sigma_B
    f_MB
    p

with optional:

    chi_wall.

But their empirical status is no longer equal.

p is promoted from a merely parsimonious geometry parameter to a quantitatively supported endpoint-shape parameter.

sigma_B and f_MB remain the parameters requiring decisive new observations or full forward-model composition.

## Decision

    p_EMPIRICAL_STATUS = PROMOTED
    sigma_B_EVENT_ORDERING = SUPPORTED
    sigma_B_MAGNITUDE = BLOCKED
    f_MB_COMPOSITE_CONSTRAINT = AVAILABLE
    f_MB_DIRECT_IDENTIFICATION = BLOCKED
    chi_wall_DEFAULT_FREE = REJECTED
    RFM_PHYSICS_CHANGE = NOT JUSTIFIED

## Next

Do not search broadly for more morphology datasets.

The next useful engineering/science step is a full conservative-tracer forward harness that combines:

    surface activation
    MB/IC split
    one-shape endpoint routing
    wall exchange
    exact tracer ledger

and compares directly to:

    Spechtacker Profile 1 calibration
    Spechtacker Profile 2 held-out profile
    95% total recovery
    measured macropore depth structure.

This is now the shortest path to determining whether f_MB becomes identifiable once p is constrained.
