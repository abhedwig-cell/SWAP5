# PPA-WU05-MIGMAC03 constitutive closeout

Date: 2026-10-05. Status: LOCAL_QUALIFICATION_COMPLETE_PENDING_CANONICAL_ADMISSION.
Base: canonical c1322db6e5551e95dcb4f86d707d22a6316f86e6.

The existing dynamic configuration accepts optional per-compartment law selectors:
0 rigid, 1 existing Kim, 2 direct Hendriks peat, 3 three-segment peat. These are
SWAP5 typed selectors; legacy soil2/input3 maps to typed law3. Absent selectors
retain the original Kim configuration. Peat parameters remain configuration;
accepted dynamic volume and water retain the existing sole owners and restart.
Minimum subsidence and candidate geometry use the same constitutive dispatcher.
Rigid compartments explicitly return zero shrink/subsidence/dynamic volume.

Direct regular Hendriks requires positive alpha and beta>alpha+1e-8, both <=100,
0<transition<saturation moisture ratio and 0<=zero-moisture void<saturation.
Piecewise breakpoints must be strictly ordered and void values physically ordered.
Each peat evaluation rejects nonfinite/unphysical void volume rather than injecting
an invalid source. No generic compatibility with all raw legacy input ranges follows.

Independent 60-digit Decimal values verify the nonlinear law. Fixed segment values
and continuity checks verify all segments. Exact authority-pinned B1.11 SHRINK
extraction compares 2002 moisture evaluations across both peat laws with maximum
error 5.551115123125783e-17, identical at O0/O2. Rigid initialization in legacy uses
an unassigned VoidR; SWAP5 corrects that undefined-state path explicitly.

Reference runtime tests cover both laws and alternating rigid/peat profiles:
dry growth, coherent wetting/contraction and displacement, accepted geometry,
reject/smaller retry, A/B/A, and restart from accepted boundaries. O0/O2 outputs
are byte-identical. Existing Kim unchanged/enabled identity and two-domain rapid
drain composition pass. A8/A10/MIGMAC01/PERCH20 preservation gates pass. No water
or Richards tolerance was relaxed. Source postimages, commands and receipts are
pinned in integration/audits/PPA_WU05_MIGMAC03_QUALIFICATION.json.

Excluded: parameter fitting, mixed Kim/peat runtime, new mixed-law rapid-drain
reference construction, general surface-owner/coupling combinations, official
whole-model equivalence, RossFast and concurrent MultiSWAP.
