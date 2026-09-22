from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "src/runtime/mod_fmr_serialized_reference_backend.f90"
BRIDGE = ROOT / "tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90"
OUT_BACKEND = ROOT / "tests/fgc/.g21l_mod_fmr_serialized_reference_backend.f90"
OUT_BRIDGE = ROOT / "tests/fgc/.g21l_mod_fgc44_real_swap_c_bridge.f90"

EXPECTED_BLOBS = {
    BACKEND: "9bd344a83afd5e10b96178933362dbb7eeea4f30",
    BRIDGE: "2151e99953fa3f8f12ebf21cc123e4c03a47e855",
    ROOT / "src/legacy/b1_10_port/headcalc.f90": "3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55",
}

def require(cond: bool, msg: str) -> None:
    if not cond:
        raise SystemExit(msg)

def blob_sha(path: Path) -> str:
    return subprocess.check_output(["git", "hash-object", str(path.relative_to(ROOT))], cwd=ROOT, text=True).strip()

for path, expected in EXPECTED_BLOBS.items():
    require(blob_sha(path) == expected, f"G21L pinned source blob drift: {path}")

backend = BACKEND.read_text()
bridge = BRIDGE.read_text()
require("research_residual_snapshot" not in backend, "G21L production backend already contains research observer")
require("fgc44_g21l_residual_snapshot_c" not in bridge, "G21L standard FGC44 bridge already contains research observer")

type_anchor = "    procedure, public :: observation => fmr_serialized_backend_observation\n"
require(backend.count(type_anchor) == 1, "G21L backend type anchor drift")
backend = backend.replace(
    type_anchor,
    type_anchor + "    procedure, public :: research_residual_snapshot => fmr_serialized_backend_research_residual_snapshot\n",
    1,
)

function_anchor = """  end function fmr_serialized_backend_observation

  subroutine fmr_serialized_capture_attempt_context"""
require(backend.count(function_anchor) == 1, "G21L backend observation anchor drift")
observer = r"""  end function fmr_serialized_backend_observation

  subroutine fmr_serialized_backend_research_residual_snapshot(self, available, residual_sum, residual_max_abs, &
       residual_l2_half, max_index, max_signed, nonconverged_balance_count, nonconverged_head_count)
    class(fmr_serialized_reference_backend_t), intent(in) :: self
    logical, intent(out) :: available
    real(real64), intent(out) :: residual_sum, residual_max_abs, residual_l2_half, max_signed
    integer, intent(out) :: max_index, nonconverged_balance_count, nonconverged_head_count
    integer :: n

    available = .false.
    residual_sum = 0.0_real64
    residual_max_abs = 0.0_real64
    residual_l2_half = 0.0_real64
    max_signed = 0.0_real64
    max_index = 0
    nonconverged_balance_count = 0
    nonconverged_head_count = 0
    if (.not. self%initialized) return
    n = self%model%workspace%richards%active_nodes
    if (n <= 0) return
    if (.not. allocated(self%model%workspace%richards%residual)) return
    if (size(self%model%workspace%richards%residual) < n) return
    if (any(.not. ieee_is_finite(self%model%workspace%richards%residual(1:n)))) return

    residual_sum = sum(self%model%workspace%richards%residual(1:n))
    residual_max_abs = maxval(abs(self%model%workspace%richards%residual(1:n)))
    residual_l2_half = 0.5_real64 * dot_product(self%model%workspace%richards%residual(1:n), &
                                                self%model%workspace%richards%residual(1:n))
    max_index = maxloc(abs(self%model%workspace%richards%residual(1:n)), dim=1)
    max_signed = self%model%workspace%richards%residual(max_index)
    if (allocated(self%model%workspace%richards%nonconverged_balance)) then
      nonconverged_balance_count = count(self%model%workspace%richards%nonconverged_balance(1:n))
    end if
    if (allocated(self%model%workspace%richards%nonconverged_head)) then
      nonconverged_head_count = count(self%model%workspace%richards%nonconverged_head(1:n))
    end if
    available = .true.
  end subroutine fmr_serialized_backend_research_residual_snapshot

  subroutine fmr_serialized_capture_attempt_context"""
backend = backend.replace(function_anchor, observer, 1)

public_anchor = "  public :: fgc44_g21k_tolerance_probe_c\n"
require(bridge.count(public_anchor) == 1, "G21L bridge public anchor drift")
bridge = bridge.replace(public_anchor, public_anchor + "  public :: fgc44_g21l_residual_snapshot_c\n", 1)

bridge_anchor = """  end function fgc44_g21k_tolerance_probe_c

  integer(c_int) function fgc44_g15_last_trial_observation_c"""
require(bridge.count(bridge_anchor) == 1, "G21L bridge function anchor drift")
bridge_fn = r"""  end function fgc44_g21k_tolerance_probe_c

  integer(c_int) function fgc44_g21l_residual_snapshot_c(available,max_index,nonconv_balance_count, &
       nonconv_head_count,residual_sum,residual_max_abs,residual_l2_half,max_signed) &
       bind(C,name="fgc44_g21l_residual_snapshot_c")
    integer(c_int), intent(out) :: available,max_index,nonconv_balance_count,nonconv_head_count
    real(c_double), intent(out) :: residual_sum,residual_max_abs,residual_l2_half,max_signed
    logical :: ready
    integer :: idx,nbal,nhead
    real(real64) :: rsum,rmax,l2half,rsigned

    fgc44_g21l_residual_snapshot_c=1_c_int
    available=0_c_int; max_index=0_c_int; nonconv_balance_count=0_c_int; nonconv_head_count=0_c_int
    residual_sum=0.0_c_double; residual_max_abs=0.0_c_double
    residual_l2_half=0.0_c_double; max_signed=0.0_c_double
    if(.not.initialized)return
    call corrector_backend%research_residual_snapshot(ready,rsum,rmax,l2half,idx,rsigned,nbal,nhead)
    if(.not.ready)then
      fgc44_g21l_residual_snapshot_c=2_c_int
      return
    end if
    available=1_c_int
    max_index=int(idx,c_int)
    nonconv_balance_count=int(nbal,c_int)
    nonconv_head_count=int(nhead,c_int)
    residual_sum=real(rsum,c_double)
    residual_max_abs=real(rmax,c_double)
    residual_l2_half=real(l2half,c_double)
    max_signed=real(rsigned,c_double)
    fgc44_g21l_residual_snapshot_c=0_c_int
  end function fgc44_g21l_residual_snapshot_c

  integer(c_int) function fgc44_g15_last_trial_observation_c"""
bridge = bridge.replace(bridge_anchor, bridge_fn, 1)

OUT_BACKEND.write_text(backend)
OUT_BRIDGE.write_text(bridge)
print("GC_FIXED_INTERFACE_G21L_RESEARCH_OBSERVER_PREPARED=PASS")
