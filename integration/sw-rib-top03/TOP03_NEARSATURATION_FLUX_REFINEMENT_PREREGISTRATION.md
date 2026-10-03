# Near-saturation integrated-flux refinement diagnostic

Date: 2026-10-03  
Status: PREREGISTERED_DIAGNOSTIC_ONLY  
Scope: same BASE imposed-head probe, widths 0.2 and 2 cm, extended to 64 and 128 substeps per forcing window.

## Question

The 16/32-step diagnostic showed nearly identical endpoint soil states in several windows while integrated top and bottom transfers still differed by about 0.01–0.08 cm. This second diagnostic tests whether these flux-ledger differences continue to contract under another factor-of-two refinement, independently of endpoint state convergence.

## Method and gates

Keep the exact fixture and all parameters from the prior diagnostic. Add only refinements 64 and 128 for each of the four windows and both previously tested widths. Report endpoint state and integrated top/bottom transfer discrepancies separately, plus all completion and existing soil/combined-mass gates. Require exact O0/O2 output identity. No temporal norm or acceptance threshold will be selected; the result only characterizes refinement behavior. Do not change constitutive width, boundary mode, forcing, or solver tolerances in response to a failure.

The existing FMR identity gate and shared temporal-acceptance prerequisite remain unchanged.
