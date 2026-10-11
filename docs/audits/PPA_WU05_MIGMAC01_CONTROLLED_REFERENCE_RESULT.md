# MIGMAC01 controlled reference result
Date: 2026-10-02
Status: LOCAL_SOURCE_EVENT_VERIFIED_NOT_SWAP5_QUALIFICATION
Preregistered on a20b15ed3e45cd9ccba491ed00e64223c3cd1e38.

The fixed modified-Andelst experiment found the first chronological active step
at t1900=35796.986000000004, dt=0.002 day. Top node=3, 5 domains, 112 nodes.
Accepted-origin covering head=-0.6622298178070477 cm; accepted head=+0.09997836037968703 cm.
Covered transfer=6.0543248402701375e-5 cm. Matrix receipt is its exact negative.
Macro balance including independent other exchange and rapid drainage closes
to 2.0973891026732083e-16 cm. Machine-readable checks and full origin/candidate
extraction are persisted. This resolves missing active source-state evidence;
it does not qualify the SWAP5 fixture or admit production behavior.

The unmodified official Andelst case has Z_TP=0. The preregistered sole physical
change was Z_TP=-2 cm. This is MODIFIED_ANDELST_COVERED_TOP, never described as an
unmodified official case. Forcing, initial state, hydraulics, drainage and
reference numerical tolerances were unchanged. Diagnostic stop occurs after
the first selected accepted event; no full-season qualification is claimed.

Exact expanded B1.11 source: all 63 files independently manifest-verified against
canonical reference identity (1886519 bytes; manifest 24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2).
Local cache /tmp/c3-b111-source supplied the verified expanded source; the uploaded
SWAP.ZIP did NOT match canonical nested-archive identity and is not claimed as a
successful reconstruction source. Compiler: GNU Fortran 13.3.0; canonical DEC
branch selection from b0_source_runner.py; O2, linux, finit-local-zero,
fallow-argument-mismatch. TTUTIL infrastructure came from uploaded
TTUTIL_4.27_testbank/vendor/TTUTIL. No reference physics repairs were made.

Reproduction: set B111_SOURCE to independently verified exact expanded B1.11,
TTUTIL_SOURCE to that vendor folder, ANDELST_CASE to official cases/3.macroporeflow,
and FC to GNU Fortran. Run tools/vq/migmac01_build_reference.py then
tools/vq/migmac01_instrument_reference.py from repository root. Recompile only
selected/macropore.f90 and selected/soilwater.f90 into reference-run/swobj with
the build flags; relink all swobj objects and ttobj/libttutil.a. Run executable
from reference-run/case with ./swap.swp, then tools/vq/migmac01_verify_capture.py.
The instrumentation must be applied once to newly selected source.
It copies model state to diagnostic SAVE arrays and never writes physical fields.
Additional read-only configuration rows were added and the identical fixed
experiment rerun; time, head and receipt remained identical.

Full CSV schema: ORIGIN_NODE holds z,dz,h,theta,matrix fraction,root,irrigation,
drainage,k,dimoca,static volume,diameter,24 cofgen values,dynamic volume,
then 8 rows per domain: sorptivity,theta reference,absorption time,volume,water,
domain fraction,wet wall,previous wet wall. END_DOMAIN holds the corresponding
8 values plus matrix exchange,interflow in,matrix saturated in,matrix saturated
out,unsaturated out. Node/domain configuration, source levels and rapid-drain
parameters are additional labeled rows. Rates multiply dt to obtain amounts.
The exact source receipt is slightly lagged from the final nonlinear head:
final-head B1.11 potential=6.05300043985638e-5 cm versus actual receipt
6.0543248402701375e-5 cm. This is recorded rather than erased by a new tolerance.

Next: bind this frozen source origin and configuration to Reference-Richards,
with explicitly declared boundary replay semantics before observing SWAP5
outputs. Preserve the negative synthetic fixture as evidence. No parameter
sweep, tolerance relaxation, or covered-top external rainfall shortcut.
Reject/replay/restart and fresh PERCH20/PERCH21/A9/A10 preservation remain pending.
Canonical shared backend reconciliation remains pending. M2 and frozen Status-A
denominator are unchanged.
