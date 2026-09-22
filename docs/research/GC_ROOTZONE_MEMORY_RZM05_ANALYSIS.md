# GC-RZM05 qualification analysis

Date: 2026-09-22  
Decision: **QUALIFIED_ROOTZONE_MANAGEMENT_BINDING**

Workflow 35706500324 completed successfully. RZM05 passed 9/9 tests and all
RZM01-RZM04 regressions remained green.

The qualified result is that the Ribasim root-zone demand semantics compose
cleanly with the dynamic analytical SWAP state. Irrigation request is frozen
from committed root storage. Delivered irrigation is an external root-zone
input booked once. Shortage is diagnostic only. The next request is derived
from accepted root storage after forcing and hydraulic redistribution.

This matters for coupling architecture because management has changed the
internal memory without creating another groundwater interface. Even in the
test with capillary groundwater supply, E_c remains the only SWAP-MODFLOW
transfer. Irrigation and capillary supply therefore have distinct ownership
despite both being able to increase root-zone water.

## Analytical ladder decision

RZM01-RZM05 now establish a bounded ladder from linear memory through forcing
order, bidirectionality, nonlinearity and management. The remaining Phase H
question cannot be answered by enriching this dummy further: real SWAP must be
used as a falsification target.

The next unit will therefore map the analytical claims to observable real-SWAP
quantities and preregister paired-state experiments. It will not alter
production coupling before those observations exist.
