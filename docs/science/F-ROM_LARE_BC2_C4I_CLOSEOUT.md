# F-ROM-LARE BC2-C4I closeout

Formal decision: C4I_RECONSTRUCTION_BLOCKED.

C4I tested a C1-smooth quadratic pressure profile psi(x)=a x+b x^2, constrained only by the existing lower-domain states Wb, Wt and H. The candidate added no prognostic state and used no response fit.

The first execution exposed a reporting bug after reconstruction failure. That bug was repaired without changing the candidate, frozen starts, root solver, hard gates or comparison rules. The authoritative rerun is workflow 35466871058 at head 1b45d0577f1086415935472b98bea644786af541.

## Main result

The 2.5 cm candidate is not uniquely identifiable at the initial Reference state. For HOLD, RISE and FALL, all four frozen starts yield physically admissible roots of the two storage constraints, but the resulting (a,b) pairs do not agree within the preregistered uniqueness tolerance. The result is AMBIGUOUS_RECONSTRUCTION, not a root-solver failure.

This conclusion is bounded to the tested quadratic profile family. It does not establish that Wb/Wt/H are insufficient for every possible gradient closure.

Two additional hard gates also fail. The maximum 64-vs-128 qH difference is about 1.91e-8 cm/d, above the frozen 1e-8 cm/d gate. The manufactured hydrostatic a=1 recovery residual reaches about 1.07e-10, marginally above the 1e-10 gate.

## 5 cm subset

The 5 cm reconstruction completes, but is not a transferable replacement.

Under WT_FALL, qi RMS improves from about 0.492 to 0.327 cm/d and qH RMS from about 1.026 to 0.798 cm/d.

Under WT_RISE, the direction reverses: qi RMS worsens from about 0.630 to 1.196 cm/d, while qH RMS worsens from about 1.473 to 2.004 cm/d.

Under WT_HOLD, TERMINAL_SIDE_LINEAR retains near-zero flux errors around 1e-10 cm/d, whereas the quadratic reconstruction introduces roughly 0.070 cm/d qi error and 0.062 cm/d qH error.

## Consequence

C4I authorizes no root-selection heuristic, direction switch, fitted branch selector or free-running corrected LARE. The next diagnostic must first characterize why the quadratic storage map is multi-valued at 2.5 cm and why the 5 cm profile helps FALL but hurts RISE.
