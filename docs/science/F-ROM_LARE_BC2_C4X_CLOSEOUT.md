# F-ROM-LARE BC2-C4X closeout

Formal decision: **C4X_B14_GW_TRANSFER_FRONTIER_PRESENT**.

C4X prospectively transfers the one-day fixed-water-table laboratory from B01 to the independently frozen B14 constitutive law. The finite-water-content initial profiles were rescaled before response generation to preserve the absolute depth of the deepest active front. The first C4X execution is explicitly non-authoritative because its exact tooling-blob provenance was stale; the authoritative rerun verifies the repaired binding before preflight and Reference generation.

The representation family transfers, but the B01 state-dimension minimum does not. Every transferred lower-zone member R3-R12 crosses both R2 and FMC on the six-component groundwater vector at every checkpoint from 0.128 through 1.024 day. Thus the B01 C4V minimum R8 is not material invariant: on B14 R3 is already the minimum tested persistent groundwater member.

At 1.024 day, R3 has approximately 0.00127 cm storage/cumulative-bottom RMSE and 0.00477 cm/d terminal bottom-flux RMSE, with zero sign errors. FMC has approximately 0.324 cm storage/cumulative RMSE and 0.579 cm/d flux RMSE; R2 has approximately 0.544 cm and 0.917 cm/d, respectively. These are comparator-relative laboratory results, not application tolerances.

Profile fidelity preserves a stronger state requirement. R3 does not cross FMC when mapped 10-cm theta RMSE is added. R8 is the minimum reduced LARE member that does, with mapped-theta RMSE about 0.00394 versus FMC 0.00633. R12 improves this further to about 0.000186.

The frozen placement controls show that state count alone is not explanatory. At dimension 4, lower-zone R4 crosses both comparators while uniform U4 fails the FMC groundwater frontier by a wide margin. At dimension 8, lower-zone R8 crosses both while uniform U8 does not. The pre-existing P4_TOP_LOWER control also crosses both, though it is less accurate than R4 on the day-one groundwater components.

The scientific conclusion is therefore material-dependent state sufficiency plus placement-dependent representation sufficiency. B14 is only a second material, so no cross-material generality or production claim is made. Application acceptance remains blocked by the C4U external H_app/A_temporal authority requirement.
