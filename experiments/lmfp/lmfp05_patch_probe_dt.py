from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: lmfp05_patch_probe_dt.py INPUT_DRIVER OUTPUT_DRIVER")

src = Path(sys.argv[1]).read_text()
old = "    step_dt = 2.0e-4_real64/real(temporal_ref,real64)"
new = "    ! F-LMFP05 derivative probe: small dt to suppress temporal contamination\n" \
      "    ! while staying above the observed Reference small-step cancellation/retry\n" \
      "    ! floor. This is a diagnostic probe, not a proposed production time step.\n" \
      "    step_dt = 2.0e-5_real64/real(temporal_ref,real64)"
if src.count(old) != 1:
    raise SystemExit(f"expected one probe-dt assignment, found {src.count(old)}")
src = src.replace(old, new)
Path(sys.argv[2]).write_text(src)
print("F-LMFP05_SMALL_PROBE_DT_PATCH PASS")
