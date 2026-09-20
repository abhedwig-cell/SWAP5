# F-ROM-LARE BC2-C5G closeout

C5G completes the matched R512/R1024 x T1/T2/T4 Reference matrix by generating only the previously missing R512 T4 cell.

The authoritative run is 35501118463. Temporal refinement progresses similarly at both spatial resolutions: the descriptive T1/T2/T4 temporal order is about 0.65 for R512 and 0.68 for R1024.

The central result is that the matched spatial gap does not shrink as time is refined. R512-R1024 bottom-flux RMSE is about 0.01928 cm/d at T1, 0.02107 at T2 and 0.02233 at T4. Thus the spatial difference increases another 6.0% from T2 to T4.

Temporal shifts are nevertheless smaller than the T4 spatial gap. T2-T4 is about 0.00469 cm/d at R512 and 0.00610 at R1024, roughly 21% and 27% of the T4 spatial gap respectively.

This means the spatial-gap change cannot be dismissed as temporal error simply dominating the comparison. Space and time discretization remain coupled in the Reference estimate. C5H therefore refines both R512 and R1024 to T8 before any R2048 or LARE comparison.
