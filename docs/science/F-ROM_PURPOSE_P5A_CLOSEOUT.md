# ROM-PURPOSE P5A closeout

**Status:** P5A_CLOSED_CONTRACT_BOUNDARY_SUPPORTED

P5A characterized the P4 SURF_P same-partition Richards numerical-domain failures without changing the solver, tolerances, histories, partitions, or fail-closed behavior.

All 18 frozen SURF_P configurations were rerun with one observability-only marker immediately before the existing local integrated residual check. The P4 pass/fail topology was reproduced exactly: 16 configurations failed and two configurations completed.

All 16 failing configurations terminated under the same mechanism:

- failure class: `RETRY_LOCAL_BALANCE`;
- balance flags positive;
- head flags zero;
- finite total residual already within the prospective representation bound;
- terminal local integrated residual above the unchanged `1.6e-15 cm` allowance;
- identical terminal diagnostic for O0 and O2;
- the original fail-closed require remained active and no failed route continued.

The two successful configurations were B14/S16/T16 and B14/S16/T32. Their maximum observed local-integrated-residual ratios remained below one.

The evidence therefore supports a numerical **contract boundary** interpretation. It does not establish that the existing allowance is too strict, and P5A does not authorize changing it.

A separate numerical-policy study would be needed to determine whether the absolute integrated-local-residual allowance should be reformulated. Such a study is outside ROM-PURPOSE representation qualification unless independently authorized.

No Layer-ROM closure claim, application-acceptance claim, production admission, or speedup claim follows from P5A.
