# C3A current-source shared preservation successor

Date: 2026-10-02. Status: registered verification, not admission.

Candidate:33e3570bb562d4803faf2e492b26166078a055a9. Canonical:7a629a10cabb3553ff77474423e6ccac81b29aec. Shared crop/runtime mandate and its held-fixed contracts remain controlling. No production equations, state, timestep, tolerance or ledger mutation is allowed here.

Exact FKT22 compile/runtime and A9/A10/RFM-state-layout replays pass at O0/O2. Original EB-I25 gate fails on the same outflow rejection assertion using both candidate and canonical backend. This alone is not a C3A regression. The original fixture and guards remain unchanged.

The existing EB-I25 runtime explicitly publishes TOP_OUTFLOW_UNQUALIFIED and withholds top advective enthalpy when a physically accepted water trajectory contains outflow. Thermal qualification does not own water admission. Register a separate successor fixture: retain all other original assertions, require one water commit, revision1, hard mass <=1e-12, two accepted-half samples, explicit outflow-unqualified status and incomplete thermal materialization. Run it against candidate and canonical source and require identical outcomes at O0/O2. This does not qualify outflow energy or repair the original historical fixture.

Run existing Black/Boesten process/runtime fixtures unchanged through the separate source-hashed compile runner. Their original work-unit diff guards are not weakened, bypassed or claimed green. This successor qualifies numerical preservation only and records historical guard limitations.

Locators:tests/physics/run_bartholomeus_shared_preservation.py and tests/physics/test_c3a_eb_i25_current_successor.f90. Persist exact source hashes, results and negative findings. Canonical admission remains open until semantic preservation and documentation qualify.
