# F-ROM-LARE BC2-C5E closeout

C5E extended the B14 dynamic prescribed-head Richards Reference to R512 and R1024 under the unchanged C5A-C5D numerical policy. No LARE representation or closure was run.

The authoritative run is 35500351323 at execution head 54961ef725868bf3ea17feccedb116634cef3da9. Both R512 and R1024 pass O0/O2 identity and all mass and transaction gates. The exact result SHA-256 is 80288f4dbc6d7fce59aef7c92226de702a8506810c3c49debf486abcf906e75a.

The spatial-refinement behavior improves materially. Adjacent-grid bottom-flux RMSE is 0.04361 cm/d for R128-R256, 0.03439 for R256-R512 and 0.01928 for R512-R1024. The descriptive observed order rises from about 0.112 in the preceding triplet to 0.343 and then 0.835.

This is substantially stronger evidence of spatial convergence than C5D, but it still does not make R1024 a continuum-like scientific truth. The Reference transaction interval, nonlinear policy and tolerances have not been jointly refined.

The next experiment is C5F: a Reference-only matched space-time audit at R512 and R1024. The exact physical histories are retained, the time interval is refined prospectively, and refined outputs are aggregated back to the original 0.0008-day observation windows. No new LARE closure or representation is authorized.
