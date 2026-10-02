# PPA-WU05-MIGMAC02 source reconciliation — crack-state semantics

Date: 2026-10-02
Status: SOURCE_SEMANTICS_RECONCILED_IMPLEMENTATION_NOT_STARTED
Canonical authority base: f8b7262ee4860bb89a40fb238a5601c3a61e6280
Recovered research authority: PPA-WU05-A3 E4, exact B1.11 MPVOLUME lines 1728-1755

## Correction to the initial MIGMAC02 hypothesis

VlMpDyCp is not merely a derived geometry view of current matrix moisture.

The exact B1.11 MPVOLUME branch uses prior dynamic crack volume in the wetting
decision. With identical current theta and previous-step theta, an existing
local or neighbouring crack can keep the compartment on the crack branch by
switching the closing threshold from ThetCrMp to ThetaS.

PPA-WU05-A3 E4 already demonstrated:

- theta = 0.35;
- previous-step theta = 0.30;
- fresh/no-crack history -> VlMpDyCp = 0;
- prior local crack = 0.08 cm -> next VlMpDyCp about 0.30928 cm;
- prior neighbouring crack = 0.08 cm -> same nonzero next crack volume.

Therefore VlMpDyCp is genuine hysteretic continuation state.

## Source operator structure recovered so far

For a shrinkage-active compartment B1.11 first requires theta below saturation
minus a small threshold. It computes a shrinkage volume from the selected soil
shrinkage relation and dz.

On wetting, if the current compartment or the relevant neighbouring compartment
already has dynamic crack volume, the crack-closing threshold is ThetaS.
Otherwise the activation threshold is ThetCrMp.

Below the active threshold the source computes a subsidence term from the
shrinkage relation and geometric shape factor and then computes nonnegative
dynamic crack volume using the matrix-area fraction and compartment geometry.

This means the next crack volume depends on:

- current matrix theta;
- previous-step/accepted matrix theta;
- prior VlMpDyCp in the current and neighbouring compartment;
- ThetaS and ThetCrMp;
- shrinkage relation selected by SWSOILSHR/SWSHRINP and its parameters;
- dz, matrix-area fraction and crack geometry factor.

## State classification

Committed physical/history state:
- VlMpDyCp.

Derived geometry from committed/candidate VlMpDyCp:
- total macropore volume;
- domain volume partition;
- domain-bottom geometry and related geometric views.

Immutable/model configuration:
- soil shrinkage model selection;
- shrinkage parameterization;
- geometry/shape parameters;
- retention/saturation thresholds needed by the source relation.

Trial matrix state:
- current theta during the nonlinear trial.

Accepted/history matrix state:
- theta_m1 used by the wetting/hysteresis branch.

## Transaction implication

Earlier source audits found VlMpDyCp mutating in MPVOLUME during nonlinear
trials and incomplete legacy rollback. That legacy mutation pattern is not a
license to mutate committed SWAP5 state inside HeadCalc.

The SWAP5 migration must preserve the physical dependency while using explicit
candidate ownership:

1. accepted VlMpDyCp remains immutable during a trial;
2. the shrinkage operator may evaluate a trial-local candidate dynamic volume
   from trial matrix theta plus accepted/history state;
3. geometry and exchange for that trial use the trial-local candidate where
   source timing requires it;
4. rejection publishes neither candidate crack state nor displaced-water
   receipt;
5. acceptance commits the candidate crack state exactly once;
6. restart persists the accepted crack state.

Whether the candidate must be refreshed within each nonlinear iteration or only
at a bounded source stage remains to be established from MPVOLUME call sites.
This timing question is the next source-reconciliation gate.

## Known source defect kept separate

SWAP 4.3.1 accepts clay with SWSHRINP=3 although the documented theory assigns
option 3 to peat. The existing issue register classifies this as a likely code
bug. MIGMAC02 must not silently canonize that invalid combination.

## Next source gate

Recover exact MPVOLUME call sites and ordering relative to MACRORATE, HeadCalc
and accepted-state publication. Then preregister one bounded shrinkage model and
a source-backed active fixture before production implementation.
