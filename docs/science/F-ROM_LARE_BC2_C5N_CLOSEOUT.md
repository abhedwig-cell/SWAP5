# F-ROM-LARE BC2-C5N closeout

C5N is the fresh blind high-resolution B14 dynamic prescribed-head discriminator.

Authority is run 35506943959 at execution head 82f36f754cdbb8747e867b1875c325d665d6405d, artifact 10604541124, digest sha256:4fdf4c551ab2e5357d911458186b6273c05b39c5a7d3d9807ee38de5e540b1d9. Result SHA-256 is 96ea7ca1f59e972d5933b2168c87ec19cea91915e6ebe9aab470c906af7ebfbe.

All 32 Reference slices qualify and all four O0/O2 route pairs are byte-identical. R2048 T8-to-T16 error is componentwise below both R512-to-R2048 and R1024-to-R2048 error on groundwater and profile views, so both spatial comparator frontiers are interpretable.

No reduced lower-zone LARE member R3-R12 crosses R512, R1024 or the R2048 temporal-floor comparator on either groundwater or profile view. Even R16 does not cross them.

The key structural finding nevertheless replicates: R4 is no worse than U4 and R8 no worse than U8 on the groundwater metric vector. U4 has 224 flux-sign mismatches and one reversal-sequence failure.

More state does not rescue the existing closure family. R5 through R16 are effectively identical on the major groundwater-response errors: interval bottom-flux RMSE remains about 0.169883 cm/d and storage/cumulative RMSE about 0.011438 cm against R2048.

C5N therefore separates vertical information placement from inter-layer propagation. Placement matters, but BC1 CURRENT_LAYER_FACE does not propagate the retained state with high-resolution prescribed-head fidelity. New layer-boundary optimization is not the next step. C5O must first reconcile which physically distinct closure families remain open after C4K-C4O.
