#!/usr/bin/env python3
from __future__ import annotations

import base64
import csv
import hashlib
import io
import json
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RECEIPT = ROOT / "F-TB13_FRESH_REPLAY_RECEIPT.json"
PARTS_DIR = ROOT / "asset_parts"
EXPECTED_ARCHIVE_SHA256 = "57a75c64e1b057223fbd32ac3051a2c56938209f19b86912d7236f4f1d5fc069"
EXPECTED_ARCHIVE_BYTES = 17122
EXPECTED_CARRIER_BYTES = 22832
EXPECTED_B1_11_MANIFEST = "24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fail(message: str) -> None:
    raise SystemExit(f"F-TB13 FAIL: {message}")


def csv_rows(data: bytes) -> list[dict[str, str]]:
    return list(csv.DictReader(io.StringIO(data.decode("utf-8"))))


def reconstruct_archive() -> bytes:
    parts = sorted(PARTS_DIR.glob("F-TB13_RECOVERED_ANALYTICAL_ASSETS.tar.gz.b64.part*"))
    if len(parts) != 4:
        fail(f"carrier part count {len(parts)} != 4")
    encoded = b"".join(path.read_bytes() for path in parts)
    if len(encoded) != EXPECTED_CARRIER_BYTES:
        fail(f"carrier byte count {len(encoded)} != {EXPECTED_CARRIER_BYTES}")
    try:
        archive = base64.b64decode(encoded, validate=True)
    except Exception as exc:
        fail(f"invalid base64 carrier: {exc}")
    if len(archive) != EXPECTED_ARCHIVE_BYTES:
        fail(f"archive byte count {len(archive)} != {EXPECTED_ARCHIVE_BYTES}")
    if sha256_bytes(archive) != EXPECTED_ARCHIVE_SHA256:
        fail("archive hash")
    return archive


def main() -> int:
    if not RECEIPT.is_file():
        fail("missing replay receipt")

    receipt = json.loads(RECEIPT.read_text(encoding="utf-8"))
    if receipt.get("schema") != "swap5.ftb13.legacy_analytical_reference_replay.v1":
        fail("receipt schema")
    if receipt.get("work_unit") != "F-TB13":
        fail("work-unit identity")
    if receipt.get("b1_11_reference", {}).get("member_manifest_sha256") != EXPECTED_B1_11_MANIFEST:
        fail("B1.11 identity")
    if receipt.get("decision") != "QUALIFIED_LEGACY_ANALYTICAL_REFERENCE_PRESERVATION_CANDIDATE":
        fail("receipt decision")

    archive_meta = receipt.get("asset_archive", {})
    if archive_meta.get("sha256") != EXPECTED_ARCHIVE_SHA256:
        fail("receipt archive pin")
    if archive_meta.get("bytes") != EXPECTED_ARCHIVE_BYTES:
        fail("receipt archive byte count")
    expected_members: dict[str, str] = archive_meta.get("members", {})
    if len(expected_members) != 9:
        fail("expected member count in receipt")

    archive = reconstruct_archive()
    materialized: dict[str, bytes] = {}
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as tf:
        actual_names = [member.name for member in tf.getmembers() if member.isfile()]
        if set(actual_names) != set(expected_members):
            fail(f"archive member set: {actual_names}")
        for name, expected_sha in expected_members.items():
            member = tf.getmember(name)
            handle = tf.extractfile(member)
            if handle is None:
                fail(f"cannot read archive member {name}")
            data = handle.read()
            if sha256_bytes(data) != expected_sha:
                fail(f"member hash {name}")
            materialized[name] = data

    steady = csv_rows(materialized["expected/steady_state_water_summary.csv"])
    if len(steady) != 12 or any(row.get("run_status") != "PASS" for row in steady):
        fail("steady-state water expected results")

    documented = csv_rows(materialized["expected/steady_state_water_vs_documented.csv"])
    if len(documented) != 12 or any(row.get("status") != "PASS" for row in documented):
        fail("steady-state documented comparison")

    sy = csv_rows(materialized["expected/srivastava_yeh_homogeneous_summary.csv"])
    if len(sy) != 12 or any(row.get("status") != "PASS" or row.get("gate_pass") != "1" for row in sy):
        fail("Srivastava-Yeh expected results")

    convergence = materialized["expected/srivastava_yeh_convergence.txt"].decode("utf-8").splitlines()
    if len(convergence) != 4 or any("PASS" not in line for line in convergence):
        fail("Srivastava-Yeh convergence")

    fresh = receipt.get("fresh_replay", {})
    if fresh.get("historical_framework_vs_b1_11_outputs") != "BYTE_IDENTICAL_FOR_ALL_4_PRESERVED_RESULT_FILES":
        fail("cross-reference replay identity")
    if fresh.get("steady_state_water", {}).get("passes") != 12:
        fail("steady replay count")
    if fresh.get("srivastava_yeh", {}).get("passes") != 12:
        fail("Srivastava-Yeh replay count")
    if fresh.get("srivastava_yeh", {}).get("coarse_to_fine_convergence") != "PASS_ALL_4_TIMES":
        fail("Srivastava-Yeh replay convergence")

    print("F-TB13_PRESERVATION_GATE=PASS")
    print("FTB13_ARCHIVE_IDENTITY=PASS")
    print("FTB13_STEADY_WATER_CASES=12/12_PASS")
    print("FTB13_SRIVASTAVA_YEH_CASES=12/12_PASS")
    print("FTB13_B1_11_CROSS_REPLAY=BYTE_IDENTICAL")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
