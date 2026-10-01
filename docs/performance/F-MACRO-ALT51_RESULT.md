# F-MACRO-ALT51 — conservative bromide depth-mass identification of endpoint-shape p

Date: 2026-10-01

Status: QUALIFIED_QUANTITATIVE_TRACER_DEPTH_RESULT / EFFECTIVE_p_IDENTIFIED / f_MB_STILL_UNIDENTIFIED

Canonical authority: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

## Purpose

Use numerical conservative-tracer observations rather than dye morphology to test the frozen one-shape RFM endpoint distribution.

## Data authority

An open echoRD scientific repository contains the original numeric testcase observations used for plot-scale sprinkler experiments.

For Weiherbach/Spechtacker:

    testcases/brspecht.dat

contains 10 depth rows x 20 lateral cells.

The accompanying notebook assigns depth centers:

    -0.05, -0.15, ..., -0.95 m

and explicitly separates:

    columns 1-10  = Profile 1
    columns 11-20 = Profile 2.

The source study sampled equal 10 x 10 x 10 cm cells in vertical tracer profiles.

The same repository contains the sprinkler forcing:

    total applied water = 0.021 m
    irrigation duration = 4680 s

and measured macropore-share/depth information.

For independent out-of-system comparison the Colpach/Attert testcase contains:

    testcases/brprofileXI.dat

with 15 depth rows x 5 lateral cells and depth centers:

    -0.025, -0.075, ..., -0.725 m.

The echoRD repository documents these as observed Br tracer recovery profiles and distributes scientific data under CC BY-NC-SA 4.0.

ALT51 does not copy the raw external data into SWAP5; the research script consumes the source files by path.

## Observation operator

Because every sampled cell within a profile has equal volume, the tracer values can be normalized over depth without knowing the absolute unit label:

    m_i = sum of Br observation over lateral cells at depth bin i

    f_i = m_i / sum_j m_j.

No absolute tracer-recovery fraction is claimed.

For the frozen RFM one-shape structural connectivity:

    C(x) = 1 - x^p

the cumulative fraction of terminating IC pathways by normalized depth x is:

    F_end(x) = x^p.

If retained conservative tracer mass by depth is proportional to IC endpoint deposition, the expected mass in a normalized depth bin [a,b] is:

    P_bin = b^p - a^p.

This produces a parameter-free normalized observation shape apart from p.

## Spechtacker result

### Profile 1

Best fit:

    p_eff = 0.249
    R2    = 0.985

Bootstrap over lateral cells:

    approximate 95% interval = 0.175 - 0.340.

Observed normalized tracer centroid:

    ~0.176 m.

### Profile 2

Best fit:

    p_eff = 0.219
    R2    = 0.981

Bootstrap:

    approximate 95% interval = 0.147 - 0.298.

Observed centroid:

    ~0.148 m.

The two physically separate vertical profiles therefore give closely consistent p_eff values and strongly overlapping uncertainty intervals.

This is the first quantitative replicate evidence in the RFM line that a one-shape endpoint distribution can describe conservative tracer depth mass well.

## Independent Colpach result

The same operator, without changing its form, gives:

    p_eff = 0.385
    R2    = 0.902

Bootstrap over five lateral columns:

    approximate 95% interval = 0.288 - 0.504.

Observed centroid:

    ~0.227 m.

The fitted value differs from Spechtacker, which is expected if p is a structural-profile parameter rather than a universal constant.

More importantly, the same one-parameter endpoint-mass form remains a good description in a different soil/catchment testcase.

## Contrast with ALT49 dye result

ALT49 found that visible stained fraction could not generally be represented as:

    A * [1 - x^p].

ALT51 now shows that normalized conservative bromide depth mass is much better represented by the endpoint-mass distribution implied by x^p.

This supports the earlier distinction:

    flow morphology != conservative water/tracer mass.

The failure of the dye observation operator therefore should not have been used to reject one-shape connectivity.

## What is identified

ALT51 identifies:

    p_eff,retained-tracer-depth

for each structural experiment.

It provides strong evidence that p is empirically identifiable from quantitative conservative tracer depth profiles.

## What is not yet identified

ALT51 does NOT yet prove:

    p_eff == structural RFM p

exactly.

The retained bromide profile can also be shaped by:

- matrix-macropore exchange;
- travel time;
- incomplete recovery;
- continued matrix redistribution before sampling;
- pathways leaving below the sampled profile.

Thus p_eff is the correct direct observation-space target for a full RFM tracer-routing simulation.

A source-level RFM run should predict the tracer profile and compare in observation space; p must not simply be set equal to p_eff without that routing check.

## f_MB limitation

The observed profile alone does not identify f_MB.

Deep/missing tracer could have:

- left below the sampled domain;
- remained in unsampled storage;
- been diluted;
- or followed continuous pathways.

Without a closed applied-versus-recovered tracer mass balance, assigning missing mass to MB would be unjustified.

Therefore:

    f_MB_FROM_MISSING_BROMIDE = REJECTED.

## Decision

    NUMERIC_WEIHERBACH_BROMIDE_DATA = FOUND
    CONSERVATIVE_TRACER_DEPTH_OPERATOR = QUALIFIED
    ONE_SHAPE_ENDPOINT_MASS_FIT = STRONGLY_SUPPORTED
    SPECHTACKER_REPLICATE_p_eff = CONSISTENT
    COLPACH_OUT_OF_SYSTEM_TRANSFER = SUPPORTED
    p_QUANTITATIVE_IDENTIFIABILITY = PROMOTED
    p_eff_EQUALS_STRUCTURAL_p = NOT YET ASSUMED
    f_MB_DIRECT_IDENTIFICATION = STILL BLOCKED

## Next

The next useful workunit is a frozen-RFM tracer forward model:

    accepted preferential input
      -> MB/IC split
      -> endpoint distribution C(z)=1-x^p
      -> wall exchange / retained tracer profile
      -> sampled depth-bin mass.

Use Spechtacker Profile 1 for calibration of structural p, Profile 2 as held-out within-site validation, and Colpach as out-of-system validation.

Do not alter the endpoint law before this forward-model comparison.
