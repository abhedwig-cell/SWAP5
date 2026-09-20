# F-ROM-LARE BC2-C6N2 closeout

C6N2 classifies the already-existing fixed-partition Layer-ROM family against the C6N1-qualified R2048_T32 numerical Reference uncertainty for surface-driven, fixed-bottom-flux state/profile purposes.

All 20 candidate payloads were generated successfully in source run 35537872450. A later analyzer schema-key error did not alter those payloads; aggregation-only recovery run 35538003359 reused them without rerunning candidates and produced the authoritative classification artifact 10612868344 (digest sha256:7c091b8933ce60c7e2d62229cbeb6de0a9bc68962627f6829493a796f97b08af).

The formal result is C6N2_RESOLVED_REDUCED_DIFFERENCES_ONLY. No reduced member is numerically unresolved from R2048_T32 on any declared surface/profile view for B01 or B14, so all minimum-dimension fields remain null.

This is not an application rejection. The C6N1 U_combined values are numerical discretization uncertainty bands, not hydrological tolerances.

Placement remains scientifically active and purpose-dependent. In the surface-driven workload U8 strongly improves over the lower-zone-focused R8 for both materials. For B14, P4_TOP_LOWER is also no worse than R4 on the declared surface/root-zone relation. For B01, R3, R4 and P4_TOP_LOWER leave the qualified domain on U03, demonstrating that overly sparse/nonuniform support can sacrifice domain robustness.

Even R16 remains numerically resolved from the high-resolution Reference on every declared metric. The next step is therefore not to claim a universal minimum dimension or retune CURRENT_LAYER_FACE. C6O is a read-only design reconciliation for a purpose-aligned surface representation whose coordinates must come from declared hydrological support regions, not from fitting C6N2 residuals.
