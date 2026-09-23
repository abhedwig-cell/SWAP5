from __future__ import annotations

from dataclasses import dataclass
from collections import defaultdict

@dataclass(frozen=True)
class Transfer:
    identity: str
    amount_m3: float

ROUTES = {
    "LOWER_DRAINAGE": ("SWAP_TO_RIBASIM", "drainage"),
    "RAPID_DRAINAGE": ("SWAP_TO_RIBASIM", "drainage"),
    "TOP_RUNOFF": ("SWAP_TO_RIBASIM", "surface_runoff"),
    "LOWER_INFILTRATION": ("RIBASIM_TO_SWAP_LOWER", "infiltration"),
    "TOP_INUNDATION": ("RIBASIM_TO_SWAP_TOP", "top_pump"),
}

CASES = {
    "T1_INCOMING_SPLIT": [
        Transfer("LOWER_DRAINAGE", 0.002),
        Transfer("RAPID_DRAINAGE", 0.003),
        Transfer("TOP_RUNOFF", 0.004),
    ],
    "T2_OUTGOING_SPLIT": [
        Transfer("LOWER_INFILTRATION", 0.004),
        Transfer("TOP_INUNDATION", 0.003),
    ],
    "T3_MIXED_IDENTITIES": [
        Transfer("LOWER_DRAINAGE", 0.003),
        Transfer("RAPID_DRAINAGE", 0.002),
        Transfer("TOP_RUNOFF", 0.002),
        Transfer("LOWER_INFILTRATION", 0.003),
        Transfer("TOP_INUNDATION", 0.001),
    ],
    "T4_TOP_INUNDATION_AVAILABILITY_LIMITED": [
        Transfer("TOP_INUNDATION", 0.0051),
    ],
}

EXPECTED = {
    "T1_INCOMING_SPLIT": dict(drainage=0.005, surface_runoff=0.004, infiltration=0.0, top_pump=0.0),
    "T2_OUTGOING_SPLIT": dict(drainage=0.0, surface_runoff=0.0, infiltration=0.004, top_pump=0.003),
    "T3_MIXED_IDENTITIES": dict(drainage=0.005, surface_runoff=0.002, infiltration=0.003, top_pump=0.001),
    "T4_TOP_INUNDATION_AVAILABILITY_LIMITED": dict(drainage=0.0, surface_runoff=0.0, infiltration=0.0, top_pump=0.0051),
}

def aggregate(transfers):
    out = defaultdict(float)
    for transfer in transfers:
        if transfer.identity not in ROUTES:
            raise AssertionError(f"unknown transfer identity {transfer.identity}")
        _, endpoint = ROUTES[transfer.identity]
        if transfer.amount_m3 < 0.0:
            raise AssertionError("transfer amount must be unsigned; direction is carried by identity")
        out[endpoint] += transfer.amount_m3
    return dict(out)

def main():
    for case_id, transfers in CASES.items():
        identities = [x.identity for x in transfers]
        assert len(identities) == len(set(identities)), f"{case_id}: duplicate identity"
        agg = aggregate(transfers)
        for endpoint, expected in EXPECTED[case_id].items():
            actual = agg.get(endpoint, 0.0)
            assert abs(actual - expected) <= 1e-15, (case_id, endpoint, actual, expected)

        if case_id == "T1_INCOMING_SPLIT":
            assert {"LOWER_DRAINAGE", "RAPID_DRAINAGE"} <= set(identities)
            assert agg["drainage"] == 0.005
        if case_id == "T2_OUTGOING_SPLIT":
            assert ROUTES["LOWER_INFILTRATION"][1] != ROUTES["TOP_INUNDATION"][1]

        print(
            f"SW_RIB_SWM01_Q3B_LEDGER_CASE_PASS={case_id} "
            f"identities={','.join(identities)} aggregate={agg}"
        )
    print("SW_RIB_SWM01_Q3B_TRANSFER_IDENTITY_LEDGER=PASS")

if __name__ == "__main__":
    main()
