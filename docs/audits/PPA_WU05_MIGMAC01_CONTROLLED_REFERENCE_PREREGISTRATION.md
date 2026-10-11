# MIGMAC01 controlled B1.11 covering-layer reference experiment
Date: 2026-10-02
Status: PREREGISTERED_BEFORE_REFERENCE_OUTPUT
Owning branch: research/ppa-wu05-migmac01-covering-layer

## Fixed experiment
Use the official cases/3.macroporeflow Andelst application as input provenance,
explicitly labeled MODIFIED_ANDELST_COVERED_TOP, not an unmodified official interval.
Change exactly one physical input: Z_TP=0.0 to Z_TP=-2.0 cm.
The official 1-cm shallow grid makes this top_node=3, with node 2 as covering cell.
This is the minimal two-compartment cover matching the already-declared MIGMAC01
top_node=3 composition; its depth is fixed before viewing new output.
Retain the complete official 1998-01-01 through 1999-04-26 forcing, initial state,
hydraulics, drainage, macropore configuration and numerical tolerances.
No search over heads, cover depth, forcing, timestep or tolerances is allowed.

## Reference identity
B1.11 expanded source: 63 members, 1886519 bytes, manifest SHA256
24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2.
macropore.f90 SHA256 f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f.
macrorate.f90 SHA256 537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7.
Use exact expanded source, independently verify the entire manifest before copy.
GNU compiler selection follows tools/vq/b0_source_runner.py (linux=true,
multiswap=false, with_sss=false, with_animo=false). TTUTIL is build/input
infrastructure from the already uploaded TTUTIL_4.27_testbank vendor source;
record its identity and any compatibility limitations. No TTUTIL physics authority claim.

## Selection and instrumentation
Observe the first accepted physical step, in chronological order, satisfying
IcTopMp>1, final h(IcTopMp-1)>0 and sum(QInTopVrtDm(1:NumDm))*dt>0.
Instrument read-only diagnostics around SoilWater task 2/3:
capture the accepted origin before HeadCalc and the candidate after source MACROSTATE.
Record time/dt, forcing, matrix h/theta, all seven continuation arrays, geometry,
source-reduction factor/history, covered receipt, matrix sink, macro storage and
other exchange/rapid-drain terms. Identify instrumented source hashes separately.
An early stop after captured step is diagnostic only and does not claim full-season success.

## Outcomes and stops
If the source build or exact-source reference run fails, persist its exact failing
location and state. Do not repair unqualified reference behavior silently.
If no qualifying step exists across the fixed period, record negative evidence;
do not change configuration to manufacture activation.
If a qualifying interval exists, persist complete extraction and independent
source-equation/mass checks before modifying SWAP5's active fixture.
A positive source event alone does not qualify SWAP5, reject/replay/restart,
PERCH21/A9/A10 preservation or production admission.
Canonical backend reconciliation remains mandatory because the moving canonical
changed src/runtime/mod_fmr_serialized_reference_backend.f90 since the original base.
The frozen Status-A denominator and separate M2 geometry scope remain unchanged.
