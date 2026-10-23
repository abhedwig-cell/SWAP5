# Reactive FCT moving pulse and committed disk continuation

Baseline `eb4288359e8208bb2fb03b22c622a68315836455`. MC-SOL01 research
successor; production source, defaults and scientific interfaces unchanged.

Accuracy: actual unchanged reactive FCT and production implicit comparator on
an80cm homogeneous column, theta0.3,rho*Kf0.26,Freundlich1,q0.3cm/day,
alpha0.25cm,Dm0.02cm2/day,decay0.05/day. Cell-averaged Gaussian initially
centred25cm,sigma2cm,background1e-6;8days. Closed-form advective-dispersive
reactive Gaussian supplies an independent cell-average reference. Boundaries
remain many standard deviations from the pulse; finite-boundary tail error is
negligible relative to measured discretization errors. Compare40/80/160cells,
80/160/320 time steps, correction ON/OFF at checked O0/O2. Require conserved
mass, nonnegative state, smaller corrected L1 error than the real production
implicit comparator, and decreasing corrected errors under spatial and temporal
refinement. No claim about arbitrary nonlinear pulses or full Richards PDE
accuracy follows from this constant-coefficient analytical case.

Disk continuation: actual water/reactive FCT with Freundlich0.5/1/2 on40/80
cells and0.8/1.2 initial conductivity,4x0.1daywindows. Reuse the production
matrix joint disk codec through its trusted, physically validated reconstruction
bridge. Preserve exact water/chemical accepted bits, derivative history, clock,
revision and lineage. A research envelope binds method-source identity and the
constant fixture context, preventing ordinary low-order/cross-context resume.
Its SHA256 protects the complete payload; the production CRC and structural /
parameter checks remain authoritative after envelope extraction.

Publish one complete envelope using fsync, same-directory atomic replace and
directory fsync on the tested POSIX platform. Kill a separate publisher before
and after replacement, and require only the complete old/new joint generation
to remain authoritative. Resume in a fresh executable process and compare
endpoint payload bytes and continued ledgers to uninterrupted execution.
Reject damaged/truncated/wrong-policy/context/parameter payloads without state
publication. The existing codec is same-platform; cross-platform portability
and general application/default activation are outside this proof.

Selection: small10-source pulse driver first, then bounded real disk/water
closure at O0/O2, expected150seconds total,180second per-process ceiling.
Current composed source/raw owner and predecessor reactive capsule controls.
Full F-CI/native-year/RossFast/highest-low-air not selected for isolated research.
