# F-MACRO-TRACER01-D1S — Spechtacker initial-state source finding

Date: 2026-10-01

Status: SOURCE_LIMITATION_QUALIFIED / EXACT_VERTICAL_PROFILE_NOT_OBSERVED

## Question

Does the publication/source chain contain a full pre-irrigation 0-1 m theta(z)
profile for the Spechtacker/site-10 plot that can uniquely initialize SWAP5?

## Source finding

The 2019 LAST paper reports for Spechtacker:

    initial soil moisture at 15 cm = 27.4%

and leaves the 30, 45 and 60 cm initial-moisture entries blank for Spechtacker,
while those depths are populated for the well-mixed sites 23 and 31.

Reference:

    Sternagel et al. (2019)
    Hydrology and Earth System Sciences 23, 4249-4267
    doi:10.5194/hess-23-4249-2019

The older Weiherbach initial-condition analysis states that, for site 10,
representative initial soil moisture was measured on two nearby 4 m2 plots in
a horizontal plane in the upper 15 cm using 25 TDR points. Reported means were:

    0.271 +/- 0.02 m3/m3
    0.2695 +/- 0.02 m3/m3

with estimated point-measurement error about 0.01 m3/m3.

Reference:

    Zehe & Blöschl (2004)
    Water Resources Research 40, W10202
    doi:10.1029/2003WR002869

The experimental/dissertation description likewise describes antecedent
moisture measurement in the upper 15 cm beside the irrigation plot.

## Interpretation

The unresolved state is therefore not merely a missing digitized table in the
current SWAP5 repository. The source chain explicitly documents an upper-15-cm
initial-moisture macrostate, while a complete depth-resolved pre-irrigation
profile is not documented for Spechtacker.

No evidence was found that would justify inventing observed theta values at
30, 45, 60 cm or deeper.

Therefore:

    FULL_VERTICAL_INITIAL_PROFILE_OBSERVED = NO_EVIDENCE
    UPPER_15CM_MACROSTATE = SOURCE_BACKED
    EXACT_PUBLICATION_REPLAY = NOT_IDENTIFIABLE_FROM_AVAILABLE_INITIAL_STATE

This finding supersedes further broad searching as the default next step.
A sensitivity analysis is the scientifically cleaner route unless new primary
data become available.
