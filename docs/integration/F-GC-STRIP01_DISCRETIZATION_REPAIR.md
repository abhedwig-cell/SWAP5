# STRIP01 first native discrepancy

The first real MODFLOW run used default harmonic transmissivity averaging.
At K=0.1 m/d and 50 cells its maximum difference against the independent
arithmetic-thickness Dupuit oracle was 0.00848973793 m, exceeding the frozen
0.005 m limit. Recharge/drain residual was 5.13750847e-11 m3/d, passing.

Classification: inconsistent discrete transmissivity definitions, not evidence
of a coupling defect (SWAP was absent). Native head changed from -4.9995 m at
the drain cell to -2.97247064878 m at the symmetry cell. The failed native
execution is retained separately in native/steady_k0.1_n50.

First repair before rerun: set NPF ALTERNATIVE_CELL_AVERAGING AMT-HMK, arithmetic
saturated thickness and harmonic conductivity, matching the independent FV
oracle. Conductivity is homogeneous, so this does not change a K contrast.
No head, rate or volume tolerance changes. This is an explicit numerical
configuration choice, not a production source repair or retuned physics.
Use a different output directory to preserve the original native result.

The first repair was falsified: the discrepancy remained 0.00848973793 m.
The model still used NEWTON, whose upstream saturated-thickness weighting
does not become arithmetic-thickness solely by changing the NPF keyword.
The second configuration removes NEWTON and retains AMT-HMK. This smooth,
fully wet benchmark does not require upstream weighting for dry cells.
Both failed configurations remain evidence. All frozen limits stay unchanged.
