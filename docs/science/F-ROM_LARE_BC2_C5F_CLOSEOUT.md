# F-ROM-LARE BC2-C5F closeout

C5F separates spatial and temporal Reference error at R512/R1024 for the B14 dynamic prescribed-head workload.

The authoritative run is 35500870660 at execution head 6eca56f21bf7cfa49ff078f0785e4fdefe64b5f7. T2 qualifies at R512 and R1024, and R1024 T4 also qualifies under the unchanged numerical policy.

Temporal refinement is progressing. At R1024 the T1-T2 bottom-flux RMSE is about 0.00975 cm/d and T2-T4 is about 0.00610 cm/d, corresponding to a descriptive temporal order of about 0.676.

Temporal error is smaller than the spatial difference, but not negligible. The R512-R1024 spatial RMSE at T2 is about 0.02107 cm/d; the finest temporal shift is about 29% of that spatial gap.

Space-time interaction is visible: the R512-R1024 spatial gap grows from about 0.01928 cm/d at T1 to 0.02107 at T2, a roughly 9.3% change. Therefore the spatial convergence series should not be interpreted independently of transaction interval.

The missing cell is R512 T4. C5G will generate only that cell and complete the matched R512/R1024 x T1/T2/T4 matrix before any extension to R2048.
