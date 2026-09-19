# F-ROM-LARE CoRichards Q1 closeout

Formal decision: **ONLY_FINE_CORICHARDS_DYNAMIC_VIABLE**.

Q1 defines CoRichards as conventional Reference-Richards discretisation on exactly the same fixed vertical partition and state dimension as the corresponding LARE member. It is a comparator, not a new solver.

The authority reproduction gate passes. R16, the 16 x 10 cm no-spatial-reduction control, reproduces the existing fine Reference status map at the original observation step: ten histories qualify and the two known Se0=0.95 WET/WET_DRY histories leave the qualified near-saturation domain. O0/O2 scientific traces are deterministic and the maximum transaction mass residual is about 4.26e-14 cm.

The reduced viability curve is discontinuous. R3 was already known to have zero qualified dynamic cases. Q1 now shows the same for R4, R5, R6, R8 and R12: each retains only its three equilibrium controls, while every non-equilibrium history remains numerically blocked through 16 temporal substeps per observation interval. R16, by contrast, qualifies all seven expected physically in-domain dynamic histories plus the three equilibrium histories.

Therefore conventional same-partition Richards is not an available reduced dynamic comparator on this bounded B01 fixed-flux laboratory under the frozen strict Reference numerical authority. Dynamic viability appears only at the fine spatial discretisation, where there is no spatial reduction.

This must not be restated as “LARE is better than coarse Richards”. Q1 contains no paired hydrological-fidelity comparison, and the preregistered Q2 comparison is not authorized because no reduced CoRichards member has a dynamic common qualified cohort.

Together with C4O, the result closes the immediate fixed-partition representation comparison boundary: standard low-dimensional LARE has transferable closure limitations, while same-dimension conventional Richards is numerically unavailable for dynamic comparison at R3-R12 under current authority. The next research step is representation selection among genuinely different physical reduction families, not further scalar tuning of either current family.
