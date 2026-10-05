# PPA-WU05-MIGMAC03 constitutive shrinkage extension

Date: 2026-10-05. Preregistered before production edits.
Canonical authority: MIGMAC02 PR1019 and closeout c1322db6e5551e95dcb4f86d707d22a6316f86e6.
Local base 5c7357ade has the identical canonical tree a38af6a5340d59e5cda5c9c91d561b1266e0f57b.

Scope: direct Hendriks peat (soil 2/input 1), three-segment peat (soil 2/input 3),
and explicit rigid nodes in the existing dynamic geometry chain. Existing Kim
callers retain implicit clay selection. No second geometry or water owner.
Parameter fitting and new drain/surface ownership are excluded.

Authority: exact corrected B1.11 macropore SHA256
f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f,
SHRINKPAR lines 1004-1166, SHRINK lines 1484-1577, MPVOLUME lines 1728 onward.
Peat direct parameters are e0, moisture transition a, alpha, beta, P.
The normalized multiplier is 1+P*(r^alpha*(exp(-beta*r)-exp(-beta)))/
((alpha/beta)^alpha*(exp(-alpha)-exp(-beta))), only below a.
Three-segment parameters are e0, a, intermediate moisture i, intermediate void e_i.
Both connect to the saturation void ratio theta_s/(1-theta_s).

Negative source census: rigid SHRINK leaves VoidR unassigned, though initialization
calls it for minimum subsidence. SWAP5 rigid nodes explicitly return zero shrink
and zero dynamic crack volume. Peat input3 dispatches SHRINKPAR task5; the comment
incorrectly says soil3/input3, although the reader allows soil0..2. Task5 is a no-op.
Fit loops have no iteration ceiling and are not migrated by copying them.

Design: per-node optional selector and peat parameter carriers in the existing
configuration; absent selector retains Kim exactly. Derived minimum subsidence and
trial evaluation use one constitutive dispatcher. Rigid nodes close dynamic cracks
through existing geometry displacement, without new continuation state.
Mixed static/rigid and peat geometry is qualified without claiming legacy mixed-law
rapid-drain reference construction.

Gates: independent fixed numerical values, transitions/continuity, invalid/nonfinite
parameters and input arrays, dry/wet and mixed-node profiles; O0/O2 identity;
Reference trial, reject/smaller retry, A/B/A and accepted restart for each peat law;
MIGMAC02 and controlling A8/A10/MIGMAC01/PERCH20 preservation. Mass and solver
tolerances unchanged. Admission requires persisted exact source postimages and
matching published tree. Failures remain recorded rather than hidden.
