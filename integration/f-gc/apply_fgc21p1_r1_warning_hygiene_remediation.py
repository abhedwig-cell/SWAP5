#!/usr/bin/env python3
from pathlib import Path

TX = Path("src/transaction/mod_transaction_reference.f90")
CAN = Path("src/runtime/mod_canonical_interval_runtime.f90")
BACKEND = Path("src/runtime/mod_fmr_serialized_reference_backend.f90")

TX_OLD = """    published%covers_requested_interval = origin_t0 <= requested_t0 .and. origin_t0 >= requested_t0 .and. &\n         origin_t1 <= requested_t1 .and. origin_t1 >= requested_t1\n"""
TX_NEW = """    published%covers_requested_interval = origin_t0 == requested_t0 .and. origin_t1 == requested_t1\n"""

CAN_OLD = """          result%interface_sensitivity%covers_requested_interval = &\n               result%mass%accepted_transaction_count == 1 .and. &\n               result%interface_sensitivity%origin_t0 <= interval%t0 .and. &\n               result%interface_sensitivity%origin_t0 >= interval%t0 .and. &\n               result%interface_sensitivity%origin_t1 <= interval%t1 .and. &\n               result%interface_sensitivity%origin_t1 >= interval%t1\n"""
CAN_NEW = """          result%interface_sensitivity%covers_requested_interval = &\n               result%mass%accepted_transaction_count == 1 .and. &\n               result%interface_sensitivity%origin_t0 == interval%t0 .and. &\n               result%interface_sensitivity%origin_t1 == interval%t1\n"""


def restore_exact(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    old_count = text.count(old)
    new_count = text.count(new)
    if old_count == 1 and new_count == 0:
        path.write_text(text.replace(old, new, 1))
        print(f"FGC21P1_R1_RESTORED={path}")
        return
    if old_count == 0 and new_count == 1:
        print(f"FGC21P1_R1_ALREADY_RESTORED={path}")
        return
    raise SystemExit(
        f"FGC21P1_R1_FAIL_CLOSED unexpected predicate state {path}: "
        f"old_count={old_count} new_count={new_count}"
    )


restore_exact(TX, TX_OLD, TX_NEW)
restore_exact(CAN, CAN_OLD, CAN_NEW)

# F-GC21P1 functional transport must remain present after the scope remediation.
tx = TX.read_text()
can = CAN.read_text()
backend = BACKEND.read_text()
required = {
    "transaction accepted exchange": (tx, "accepted_bottom_outward_exchange_native"),
    "canonical aggregate": (can, "candidate_exchange = aggregate_exchange + tx%accepted_bottom_outward_exchange_native"),
    "canonical publication": (can, "bottom_outward_exchange_native"),
    "backend exact accepted exchange": (backend, "outcome%bottom_outward_exchange_native = -solve_result%bottom_flux * step_duration"),
}
for label, (text, token) in required.items():
    if token not in text:
        raise SystemExit(f"FGC21P1_R1_FAIL_CLOSED missing {label}: {token}")

print("FGC21P1_R1_SOURCE_REMEDIATION=PASS")
