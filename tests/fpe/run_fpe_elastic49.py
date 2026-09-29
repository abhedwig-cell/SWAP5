#!/usr/bin/env python3
from pathlib import Path

root=Path(__file__).resolve().parents[2]
backend=(root/"src/runtime/mod_fmr_serialized_reference_backend.f90").read_text(encoding="utf-8")
tx=(root/"src/transaction/mod_transaction_reference.f90").read_text(encoding="utf-8")

checks={
"A1_PRESSURE_EXACT":"all(full%pressure_head == half%pressure_head)" in backend,
"A1_WATER_EXACT":"all(full%water_content == half%water_content)" in backend,
"A1_PONDING_EXACT":"full%ponding_depth == half%ponding_depth" in backend,
"A1_GWL_EXACT":"full%groundwater_level == half%groundwater_level" in backend,
"A2_EQUAL_ZERO":"value = 0.0_real64" in backend,
"A3_MISMATCH_HUGE":"value = huge(0.0_real64)" in backend,
"A4_TOLERANCE_COMPARE":"temporal_ok = terr <= policy%temporal_tolerance" in tx,
"A5_REJECTION_COUNTER":"result%temporal_rejections = result%temporal_rejections + 1" in tx,
"A5_RETRY":"call reject_and_retry(result, retry_index, policy, attempt_dt)" in tx,
}
bad=[k for k,v in checks.items() if not v]
for k,v in checks.items():
    print(f"F_PE_ELASTIC49_{k}={'PASS' if v else 'FAIL'}")
if bad:
    raise SystemExit("F_PE_ELASTIC49_FAIL "+",".join(bad))

# Bounded semantic fingerprints.
start=backend.index("real(real64) function fmr_serialized_temporal_identity")
end=backend.index("end function fmr_serialized_temporal_identity",start)
body=backend[start:end]
if "maxval" in body or "norm" in body.lower() or "epsilon" in body.lower():
    raise SystemExit("F_PE_ELASTIC49_FAIL unexpected continuous-error machinery")
if body.count("huge(0.0_real64)") < 2:
    raise SystemExit("F_PE_ELASTIC49_FAIL mismatch sentinel changed")

print("F_PE_ELASTIC49_IDENTITY_ONLY=PASS")
print("F_PE_ELASTIC49_TRANSACTION_COMPARE=PASS")
print("F_PE_ELASTIC49=PASS")
