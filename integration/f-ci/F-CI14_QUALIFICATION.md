# F-CI14 qualification record

Status at materialization: `CI_PENDING`.

The focused gate must pass at GNU Fortran `-O0` and `-O2`. It pins the F-CI03 transaction core, F-CI12 temporal characterization and F-CI13 recoverable reference model. It rejects any reuse of nonlinear-solver or mass tolerances inside the temporal policy and verifies that the new adapter sources contain no file I/O.

The executable test uses a deterministic transaction backend with exact mass closure and a controlled temporal discretization bias. Passing this gate qualifies the **contract implementation only**. It does not qualify any numerical B1.10 tolerance profile and does not release the B1.10 production reference transaction route.
