#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Reuse the admitted F-GC44 build/e2e recipe, but repair only current-source
# compile ordering in a temporary research copy. The historical runner itself
# remains untouched. Current mod_reference_richards_temporal_indicator imports
# mod_b110_root_sink_provider, so the provider must precede it.
#
# G21L additionally generates temporary research-build copies of the serialized
# backend and FGC44 bridge. They add one read-only residual snapshot surface.
# Committed production/runtime/solver sources remain byte-unchanged, and the
# ordinary F-GC44 e2e gate is rerun against the instrumented research build.
PATCHED_RUNNER="tests/fgc/.dsw22-current-source-fgc44-runner.sh"
G21L_BACKEND="tests/fgc/.g21l_mod_fmr_serialized_reference_backend.f90"
G21L_BRIDGE="tests/fgc/.g21l_mod_fgc44_real_swap_c_bridge.f90"
G21M_HEADCALC="tests/fgc/.g21m_headcalc.f90"
python3 tests/research/prepare_gc_g21l_residual_observer.py
python3 tests/research/prepare_gc_g21m_headcalc_observer.py
python3 - <<'PY'
from pathlib import Path
source = Path("tests/fgc/run_fgc44_real_swap_modflow_end_to_end.sh")
target = Path("tests/fgc/.dsw22-current-source-fgc44-runner.sh")
text = source.read_text()
root_sink = "  src/solver/mod_b110_root_sink_provider.f90\n"
temporal = "  src/solver/mod_reference_richards_temporal_indicator.f90\n"
backend = "  src/runtime/mod_fmr_serialized_reference_backend.f90\n"
bridge = "  tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90\n"
headcalc = "  src/legacy/b1_10_port/headcalc.f90\n"
if root_sink not in text or temporal not in text:
    raise SystemExit("DSW22 dependency-order repair anchors not found")
if backend not in text or bridge not in text:
    raise SystemExit("G21L research-build replacement anchors not found")
if headcalc not in text:
    raise SystemExit("G21M HeadCalc replacement anchor not found")
text = text.replace(root_sink, "", 1)
text = text.replace(temporal, root_sink + temporal, 1)
text = text.replace(backend, "  tests/fgc/.g21l_mod_fmr_serialized_reference_backend.f90\n", 1)
text = text.replace(bridge, "  tests/fgc/.g21l_mod_fgc44_real_swap_c_bridge.f90\n", 1)
text = text.replace(headcalc, "  tests/research/mod_gc_g21m_residual_observer.f90\n  tests/fgc/.g21m_headcalc.f90\n", 1)
target.write_text(text)
PY

# Sourcing deliberately keeps BUILD and libfgc44_swap.so alive until this
# outer research runner exits. It still executes the complete F-GC44 e2e gate.
source "$PATCHED_RUNNER"
rm -f "$PATCHED_RUNNER" "$G21L_BACKEND" "$G21L_BRIDGE" "$G21M_HEADCALC"

test -f "$BUILD/bridge/libfgc44_swap.so" || {
  echo "GC_DSW22_FAIL missing reused F-GC44 bridge library" >&2
  exit 1
}

# The original DSW22 all-nine-success gate is immutable and was falsified
# in workflow 35564514215 at its first matrix point. Do not rerun it as a
# moving acceptance gate. Characterize the unchanged matrix instead.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_real_fgc44_response_storage_diagnostic.py | tee "$BUILD/dsw22-diagnostic.txt"

grep -Fq 'GC_DSW22D_DIAGNOSTIC_GATE=PASS' "$BUILD/dsw22-diagnostic.txt" || {
  echo "GC_DSW22D_FAIL missing diagnostic gate" >&2
  exit 1
}

echo 'GC_DSW22_PREREGISTERED_GATE=FALSIFIED_PRESERVED'
echo 'GC_DSW22D_REAL_SWAP_MATRIX_DIAGNOSTIC=PASS'

# G03/G05/G06 fixed-interface globalization qualification. This reuses the
# built real F-GC44 bridge, but every groundwater probe uses a fresh MODFLOW
# prepared solve and every SWAP trial is discarded.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_fgc44_globalization_g03.py \
  | tee "$BUILD/fgc44-globalization-g03.txt"

grep -Fq 'GC_FIXED_INTERFACE_FGC44_GLOBALIZATION_GATE=PASS' "$BUILD/fgc44-globalization-g03.txt" || {
  echo "GC_FGC44_GLOBALIZATION_FAIL missing G03/G05/G06 gate" >&2
  exit 1
}

# G07A live groundwater-regime sweep around the analytical r=1 and r=3
# transition structure. The real-SWAP response remains diagnostic-only.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_fgc44_regime_sweep_g07a.py \
  | tee "$BUILD/fgc44-globalization-g07a.txt"

grep -Fq 'GC_FIXED_INTERFACE_FGC44_G07A=PASS' "$BUILD/fgc44-globalization-g07a.txt" || {
  echo "GC_FGC44_G07A_FAIL missing live phase-transition gate" >&2
  exit 1
}


# G08 production-candidate research qualification. This is still diagnostic:
# every SWAP trial is discarded and the accepted origin/ledger must remain
# unchanged. The test re-estimates the physical tangent at each accepted trial
# and compares raw Newton (P1) with factor-1/2 safeguarded Newton (P4).
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_fgc44_safeguarded_newton_g08.py \
  | tee "$BUILD/fgc44-globalization-g08.txt"

grep -Fq 'GC_FIXED_INTERFACE_G08_EXECUTION=PASS' "$BUILD/fgc44-globalization-g08.txt" || {
  echo "GC_FGC44_G08_FAIL missing safeguarded-Newton execution gate" >&2
  exit 1
}


# The preregistered G09 all-boundary estimator gate was falsified in
# workflow 35699061533 at C3_LONG_HIGH positive edge. Preserve that result;
# do not rerun it as a moving acceptance gate.
echo 'GC_FIXED_INTERFACE_G09_FIRST_EXECUTION=FALSIFIED_PRESERVED'

# G09A fixed-scale diagnostic: characterize status topology and derivative
# estimates at the failed C3-positive state and the C2-negative control.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_fgc44_tangent_topology_g09a.py \
  | tee "$BUILD/fgc44-globalization-g09a.txt"

grep -Fq 'GC_FIXED_INTERFACE_G09A_DIAGNOSTIC=PASS' "$BUILD/fgc44-globalization-g09a.txt" || {
  echo "GC_FGC44_G09A_FAIL missing tangent-topology diagnostic gate" >&2
  exit 1
}


# The preregistered G09B all-boundary topology-consistent estimator gate was
# falsified in workflow 35700067828 at C1_LOW_FORCING negative edge.
echo 'GC_FIXED_INTERFACE_G09B_FIRST_EXECUTION=FALSIFIED_PRESERVED'

# G09C diagnostic: decompose the exact-signature failure at C1 negative against
# a qualified C0-positive control over the fixed nine-scale ladder.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_fgc44_signature_decomposition_g09c.py \
  | tee "$BUILD/fgc44-globalization-g09c.txt"

grep -Fq 'GC_FIXED_INTERFACE_G09C_DIAGNOSTIC=PASS' "$BUILD/fgc44-globalization-g09c.txt" || {
  echo "GC_FGC44_G09C_FAIL missing execution-signature diagnostic gate" >&2
  exit 1
}


# G09D stencil-internal execution-class tangent qualification.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_fgc44_stencil_class_tangent_g09d.py \
  | tee "$BUILD/fgc44-globalization-g09d.txt"

grep -Fq 'GC_FIXED_INTERFACE_G09D_EXECUTION=PASS' "$BUILD/fgc44-globalization-g09d.txt" || {
  echo "GC_FGC44_G09D_FAIL missing stencil-class tangent gate" >&2
  exit 1
}


# G10 bound B4 carrier qualification was falsified in workflow 35702164449:
# carrier binding and material nonlinearity passed, but P4 exhausted its
# 12-contraction safeguard in GW_MIXED NEG. Preserve that result.
echo 'GC_FIXED_INTERFACE_G10_FIRST_EXECUTION=FALSIFIED_PRESERVED'

# G10A diagnoses the mixed-groundwater merit/reference oracle without changing
# E3, P4, G10 tolerances, starts or production coupling.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_fgc44_groundwater_oracle_g10a.py \
  | tee "$BUILD/fgc44-globalization-g10a.txt"

grep -Fq 'GC_FIXED_INTERFACE_G10A_DIAGNOSTIC=PASS' "$BUILD/fgc44-globalization-g10a.txt" || {
  echo "GC_FGC44_G10A_FAIL missing direct-groundwater-oracle diagnostic gate" >&2
  exit 1
}


# G10B replays the frozen B4/GW_MIXED path with the prospectively frozen
# local groundwater response selected from G10A. G10 itself remains failed.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_fgc44_local_groundwater_g10b.py \
  | tee "$BUILD/fgc44-globalization-g10b.txt"

grep -Fq 'GC_FIXED_INTERFACE_G10B_EXECUTION=PASS' "$BUILD/fgc44-globalization-g10b.txt" || {
  echo "GC_FGC44_G10B_FAIL missing local-groundwater replay gate" >&2
  exit 1
}


# G11 live safeguard-recovery stress. Uses the qualified E3 tangent and a
# prospectively frozen storage-dominated groundwater stress; no tangent or
# SWAP numerical tolerance is degraded to manufacture the bad Newton step.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_fgc44_live_safeguard_g11.py \
  | tee "$BUILD/fgc44-globalization-g11.txt"

grep -Fq 'GC_FIXED_INTERFACE_G11_EXECUTION=PASS' "$BUILD/fgc44-globalization-g11.txt" || {
  echo "GC_FGC44_G11_FAIL missing live safeguard-recovery gate" >&2
  exit 1
}


# G14 research-only fused trial observation. One backend corrector run returns
# participant-style q/status plus the E3 execution-class diagnostics.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g14_fused_fgc44.py \
  | tee "$BUILD/fgc44-g14-fused.txt"

grep -Fq 'GC_FIXED_INTERFACE_G14_FGC44_FUSED_EQUIVALENCE=PASS' "$BUILD/fgc44-g14-fused.txt" || {
  echo "GC_FGC44_G14_FAIL missing fused-observation equivalence gate" >&2
  exit 1
}


# G15 production-facing building-block qualification. The actual FMR participant
# executes one normal trial per head; a read-only accessor exposes diagnostics
# from that same trial. G14 fused research observations remain the reference oracle.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g15_participant_observation.py \
  | tee "$BUILD/fgc44-g15-participant-observation.txt"

grep -Fq 'GC_FIXED_INTERFACE_G15_EXECUTION=PASS' "$BUILD/fgc44-g15-participant-observation.txt" || {
  echo "GC_FGC44_G15_FAIL missing same-trial participant observation gate" >&2
  exit 1
}


# G16 production-facing building-block qualification: the service schedules
# immutable-origin participant probes, caches exact-head observations, and
# discards diagnostic candidates through the participant. E3 remains the
# frozen research controller/oracle; no HCOF/RHS policy is exercised here.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g16_tangent_observation_service.py \
  | tee "$BUILD/fgc44-globalization-g16.txt"

grep -Fq 'GC_FIXED_INTERFACE_G16_EXECUTION=PASS' "$BUILD/fgc44-globalization-g16.txt" || {
  echo "GC_FGC44_G16_FAIL missing tangent-observation-service gate" >&2
  exit 1
}


# G17 research orchestration qualification: consume G16 for every diagnostic
# SWAP evaluation in the frozen G11 safeguard-recovery stress. Diagnostic
# probes must remain non-authoritative; only one final reacquired participant
# candidate may enter the existing FMR/ledger preflight and publication seam.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g17_safeguarded_orchestration.py \
  | tee "$BUILD/fgc44-globalization-g17.txt"

grep -Fq 'GC_FIXED_INTERFACE_G17_EXECUTION=PASS' "$BUILD/fgc44-globalization-g17.txt" || {
  echo "GC_FGC44_G17_FAIL missing safeguarded-orchestration gate" >&2
  exit 1
}


# G18 contract reconciliation. This is deliberately a compatibility/falsification
# gate: exact G11/G17 head-space P4 is compared with the already-qualified
# F-GC38/F-GC39 continuous prepared-solve ownership contract. No runtime policy
# or MODFLOW state-control primitive is added by this test.
python3 tests/research/test_gc_fixed_interface_g18_prepared_solve_p4_contract.py \
  | tee "$BUILD/fgc44-globalization-g18.txt"

grep -Fq 'GC_FIXED_INTERFACE_G18_EXECUTION=PASS' "$BUILD/fgc44-globalization-g18.txt" || {
  echo "GC_FGC44_G18_FAIL missing prepared-solve/P4 reconciliation gate" >&2
  exit 1
}


# G19 bounded response-space damping bridge. Each lambda response is solved
# from the same accepted groundwater origin; this does not yet claim continuous
# prepared-solve equivalence.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g19_response_space_bridge.py \
  | tee "$BUILD/fgc44-globalization-g19.txt"

grep -Fq 'GC_FIXED_INTERFACE_G19_EXECUTION=PASS' "$BUILD/fgc44-globalization-g19.txt" || {
  echo "GC_FGC44_G19_FAIL missing response-space damping bridge gate" >&2
  exit 1
}


# G20 continuous prepared-solve transport qualification. The already-qualified
# G19 lambda response family is traversed inside one live F-GC38 prepared solve:
# fixed XOLD, evolving X, no rollback/set-head, and no timestep publication.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g20_continuous_response_damping.py \
  | tee "$BUILD/fgc44-globalization-g20.txt"

grep -Fq 'GC_FIXED_INTERFACE_G20_EXECUTION=PASS' "$BUILD/fgc44-globalization-g20.txt" || {
  echo "GC_FGC44_G20_FAIL missing continuous prepared-solve response gate" >&2
  exit 1
}


# G21 is a persisted scientific falsification, not a positive regression gate.
# Reproduce that exact negative result before allowing downstream G21A diagnosis.
# Any success or any different failure is fail-closed and requires a new bounded
# reconciliation rather than silently changing the archived G21 verdict.
set +e
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g21_dynamic_response_globalization.py \
  2>&1 | tee "$BUILD/fgc44-globalization-g21.txt"
G21_RC=${PIPESTATUS[0]}
set -e

if [[ "$G21_RC" -eq 0 ]]; then
  echo "GC_FGC44_G21_FAIL persisted G21 falsification unexpectedly disappeared" >&2
  exit 1
fi
grep -Fq 'AssertionError: G21 accepted head drift outer=2: 7.215394948190124e-11' \
  "$BUILD/fgc44-globalization-g21.txt" || {
  echo "GC_FGC44_G21_FAIL known outer-2 falsification was not reproduced exactly" >&2
  exit 1
}
echo "GC_FIXED_INTERFACE_G21_PERSISTED_FALSIFICATION_REPRODUCED=PASS"


# G21A diagnostic decomposition of the falsified G21 outer-2 head divergence.
# This does not change any G21 gate or production policy; it separates response
# parameter sensitivity from continuous prepared-solve path dependence.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g21a_outer2_divergence.py \
  | tee "$BUILD/fgc44-globalization-g21a.txt"

grep -Fq 'GC_FIXED_INTERFACE_G21A_EXECUTION=PASS' "$BUILD/fgc44-globalization-g21a.txt" || {
  echo "GC_FGC44_G21A_FAIL missing outer-2 divergence diagnostic gate" >&2
  exit 1
}


# G21B diagnostic-only prepared-solve continuation test. Hold the exact G21A
# outer-2 affine response fixed for a preregistered 12-call tail after both a
# fresh origin and the continuous outer-1 history. This classifies solver-path
# persistence; it does not introduce a new coupling acceptance rule.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g21b_prepared_solve_convergence.py \
  | tee "$BUILD/fgc44-globalization-g21b.txt"

grep -Fq 'GC_FIXED_INTERFACE_G21B_EXECUTION=PASS' "$BUILD/fgc44-globalization-g21b.txt" || {
  echo "GC_FGC44_G21B_FAIL missing fixed-response continuation diagnostic gate" >&2
  exit 1
}


# G21C read-only XMI state forensics. Compare the frozen G21B fresh/history
# prepared-solve paths using only copied memory-manager state. No state setter,
# rollback, convergence-policy change or production mutation is permitted.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g21c_xmi_state_forensics.py \
  | tee "$BUILD/fgc44-globalization-g21c.txt"

grep -Fq 'GC_FIXED_INTERFACE_G21C_EXECUTION=PASS' "$BUILD/fgc44-globalization-g21c.txt" || {
  echo "GC_FGC44_G21C_FAIL missing read-only XMI forensic gate" >&2
  exit 1
}


# G21D paired causal-isolation diagnostic. Repeat the frozen G21B
# FRESH/HISTORY response experiment with standard MODERATE delta-bar-delta and
# with nonlinear under-relaxation disabled from solver initialization. No
# mid-solve state mutation or production configuration change is permitted.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g21d_under_relaxation_causal.py \
  | tee "$BUILD/fgc44-globalization-g21d.txt"

grep -Fq 'GC_FIXED_INTERFACE_G21D_EXECUTION=PASS' "$BUILD/fgc44-globalization-g21d.txt" || {
  echo "GC_FGC44_G21D_FAIL missing under-relaxation causal-isolation gate" >&2
  exit 1
}


# G21E matched dynamic solver-configuration comparison. Run the complete
# response-space coupling loop under standard MODERATE delta-bar-delta and
# UNDER_RELAXATION NONE. Physical endpoint qualification, strict trajectory
# fidelity and solve cost are reported separately; this does not select a
# production IMS configuration.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g21e_dynamic_solver_configuration.py \
  | tee "$BUILD/fgc44-globalization-g21e.txt"

grep -Fq 'GC_FIXED_INTERFACE_G21E_EXECUTION=PASS' "$BUILD/fgc44-globalization-g21e.txt" || {
  echo "GC_FGC44_G21E_FAIL missing dynamic solver-configuration comparison gate" >&2
  exit 1
}


# G21F local participant-admissibility boundary diagnostic. Resolve the
# outer-2 status-6/status-0 transition in binary64 head space using only G16
# immutable-origin diagnostic observations. No acceptance smoothing or production
# policy/configuration change is permitted.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g21f_admissibility_boundary.py \
  | tee "$BUILD/fgc44-globalization-g21f.txt"

grep -Fq 'GC_FIXED_INTERFACE_G21F_EXECUTION=PASS' "$BUILD/fgc44-globalization-g21f.txt" || {
  echo "GC_FGC44_G21F_FAIL missing admissibility-boundary diagnostic gate" >&2
  exit 1
}


# G21G repeatability/mechanism diagnostic. Replay all 33 G21F heads in three
# fresh G16 sessions and pair the participant result with the read-only final
# corrector-backend physical observation. No runtime execution or policy change.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g21g_island_repeatability.py \
  | tee "$BUILD/fgc44-globalization-g21g.txt"

grep -Fq 'GC_FIXED_INTERFACE_G21G_EXECUTION=PASS' "$BUILD/fgc44-globalization-g21g.txt" || {
  echo "GC_FGC44_G21G_FAIL missing island repeatability/mechanism gate" >&2
  exit 1
}


# G21H isolated retry-level physical-solver forensics. Reconstruct the nine
# frozen retry durations independently from one immutable origin using a
# test-only max_retries=0 config copy. This diagnoses the deterministic G21G
# island mechanism without changing production solver or transaction policy.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g21h_retry_level_forensics.py \
  | tee "$BUILD/fgc44-globalization-g21h.txt"

grep -Fq 'GC_FIXED_INTERFACE_G21H_EXECUTION=PASS' "$BUILD/fgc44-globalization-g21h.txt" || {
  echo "GC_FGC44_G21H_FAIL missing isolated retry-level forensic gate" >&2
  exit 1
}


# G21I final-retry Newton iteration-prefix tomography. Repeat the exact G21H
# smallest-duration attempt with copied solver parameters and max_iterations
# prefixes 1..16 to localize adjacent-head backtracking/convergence branching.
# Production HeadCalc remains byte-unchanged.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g21i_solver_prefix_forensics.py \
  | tee "$BUILD/fgc44-globalization-g21i.txt"

grep -Fq 'GC_FIXED_INTERFACE_G21I_EXECUTION=PASS' "$BUILD/fgc44-globalization-g21i.txt" || {
  echo "GC_FGC44_G21I_FAIL missing solver-prefix tomography gate" >&2
  exit 1
}


# G21J convergence-criterion causal isolation. At the exact G21I split
# iterations, relax only copied HEAD/TOTAL/POND convergence criteria in all
# preregistered subsets while keeping compartment balance untouched in the
# primary arms. Secondary compartment interventions are diagnostic only.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g21j_convergence_criteria.py \
  | tee "$BUILD/fgc44-globalization-g21j.txt"

grep -Fq 'GC_FIXED_INTERFACE_G21J_EXECUTION=PASS' "$BUILD/fgc44-globalization-g21j.txt" || {
  echo "GC_FGC44_G21J_FAIL missing convergence-criterion isolation gate" >&2
  exit 1
}


# G21K path-preserving balance-threshold tomography. Bracket the B2 total
# balance and B1 compartment-balance predicate using copied numerical
# parameters only; no diagnostic tolerance becomes a runtime proposal.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g21k_balance_thresholds.py \
  | tee "$BUILD/fgc44-globalization-g21k.txt"

grep -Fq 'GC_FIXED_INTERFACE_G21K_EXECUTION=PASS' "$BUILD/fgc44-globalization-g21k.txt" || {
  echo "GC_FGC44_G21K_FAIL missing balance-threshold tomography gate" >&2
  exit 1
}

# G21L direct final-residual observation. The shared library was built from
# temporary research-only backend/bridge copies with a read-only workspace
# observer. Production src/** and the standard FGC44 bridge remain untouched.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g21l_residual_state.py \
  | tee "$BUILD/fgc44-globalization-g21l.txt"

grep -Fq 'GC_FIXED_INTERFACE_G21L_EXECUTION=PASS' "$BUILD/fgc44-globalization-g21l.txt" || {
  echo "GC_FGC44_G21L_FAIL missing direct residual-state gate" >&2
  exit 1
}

# G21M residual arithmetic/cancellation qualification.
# CI rerun after technical HeadCalc instrumentation-anchor repair. A temporary HeadCalc
# copy records the already-computed final residual vector and node-4 signed
# expression terms; independent arithmetic is performed without changing them.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g21m_residual_arithmetic.py \
  | tee "$BUILD/fgc44-globalization-g21m.txt"

grep -Fq 'GC_FIXED_INTERFACE_G21M_EXECUTION=PASS' "$BUILD/fgc44-globalization-g21m.txt" || {
  echo "GC_FGC44_G21M_FAIL missing residual arithmetic qualification gate" >&2
  exit 1
}
