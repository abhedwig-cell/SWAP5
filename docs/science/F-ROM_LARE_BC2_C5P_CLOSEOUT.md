# F-ROM-LARE BC2-C5P closeout

C5P is a fresh blind fixed-dimension discriminator of bottom-adjacent state placement under unchanged BC1 CURRENT_LAYER_FACE closure.

Authority is workflow run 35507762232 at execution head c6f5ef73106edc64ce91e4d1a074a881e41225e3, artifact 10604607315, digest sha256:44837e7386c1a4f275bdd88135c2ce5ed1fb385907ee671248933faed7300928. The exact result SHA-256 is abdfc5f978c530881342bb61ddb60d6f9136b90445ec4c11d3215abd39a81fc0.

Reference temporal quality passes prospectively. R1024-to-R2048 bottom-flux RMSE is 0.00844673 cm/d, while R2048 T8-to-T16 is 0.00171915 cm/d.

Bottom-focused placement materially improves the same-dimension representation. D8 is especially clean: B10 -> B5 -> B2P5 is componentwise non-worsening for both groundwater and mapped-profile views. At B2P5, storage/cumulative error is about 23% of D8_B10, mapped-profile error about 24%, per-history signed-bias error about 12%, and flux RMSE about 74%.

D4 shows why boundary focus alone is not the answer. D4_B5 improves cleanly, but D4_B2P5 introduces 25 sign mismatches and a 25-observation-step reversal penalty even while its continuous error magnitudes decrease. Sufficient vertical memory away from the immediate lower boundary still matters.

No focused member reaches the R1024 high-resolution comparator. D8_B2P5 remains roughly 14.8x the R1024-R2048 flux gap and much farther away on storage, signed bias and profile state.

C5P therefore establishes bottom-adjacent placement as a causal representation variable, but not as a sufficient remedy. It also does not uniquely identify a closure floor. C5Q must first distinguish missing broader vertical memory from missing propagation physics before any new closure implementation is authorized.
