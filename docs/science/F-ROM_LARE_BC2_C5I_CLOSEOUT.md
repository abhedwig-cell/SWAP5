# F-ROM-LARE BC2-C5I closeout

C5I is the preregistered final matched temporal refinement before either a new spatial Reference level or a mechanism audit.

The authoritative scientific evidence is run 35502856809, execution head a8edf922bcd02c10cd591d6f65dd72d38193404b, artifact 10602539613, digest sha256:8d7d4be3b428bbc30a7c48c2e81a448318c252d80b053caa748b7df7580a1664. The exact result SHA-256 is 865339e6bd85eb86d5b905de1af9a7e87321878d3ae47e6f2e7ee9b70a08b302.

Because long R1024 T16 processes repeatedly received external runner SIGTERM, execution was partitioned by history. All 16 geometry x optimization x history slices qualified, then Z01-Z04 were concatenated in fixed order. Reconstructed O0 and O2 trajectories are byte-identical at both R512 and R1024. This changed execution topology only, not science.

The matched R512-R1024 bottom-flux RMSE is about 0.02233 cm/d at T4, 0.02303 at T8 and 0.02340 at T16. Thus it continues to increase, although the increment shrinks to about 1.59% from T8 to T16.

Temporal error continues to decrease. T8-T16 RMSE is about 0.00147 cm/d at R512 and 0.00180 at R1024, only about 6.3% and 7.7% of the matched T16 spatial gap. Descriptive temporal orders are about 0.887 and 0.920.

The remaining high-resolution disagreement is therefore spatial/boundary dominated rather than temporal dominated under this frozen workload. As in earlier diagnostics, HOLD is zero or machine-level and differences occur during prescribed-head phases.

C5I activates the preregistered stop rule: no default T32 and no R2048. C5J must first diagnose the discrete prescribed-head boundary formulation without changing production Reference Richards.
