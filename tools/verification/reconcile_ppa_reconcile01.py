#!/usr/bin/env python3
"""Inventory PR700 against an exact canonical ref; never infer physical equivalence.

Only Git identity and lexical Fortran declaration matches are classified. Owner
routes are navigation hints, not admission or supersession decisions. The archive
contains every changed historical postimage, including unselected source/tests.
"""
import argparse
import base64
from collections import Counter, defaultdict
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile


def git(*args):
    return subprocess.check_output(["git", *args])


def tree(ref):
    result = {}
    for item in git("ls-tree", "-rz", ref).split(b"\0"):
        if item:
            header, path = item.split(b"\t", 1)
            mode, kind, blob = header.decode().split()
            if kind == "blob":
                result[path.decode()] = (mode, blob)
    return result


def blobs(ids):
    ordered = sorted(set(ids))
    data = subprocess.run(["git", "cat-file", "--batch"],
                          input=("\n".join(ordered) + "\n").encode(),
                          stdout=subprocess.PIPE, check=True).stdout
    offset, result = 0, {}
    for expected in ordered:
        end = data.index(b"\n", offset)
        actual, kind, size = data[offset:end].decode().split()
        assert actual == expected and kind == "blob"
        offset = end + 1
        size = int(size)
        raw = data[offset:offset + size]
        assert hashlib.sha1(b"blob " + str(size).encode() + b"\0" + raw).hexdigest() == actual
        result[actual] = raw
        offset += size + 1
    assert offset == len(data)
    return result


def declarations(raw):
    # Lower-bound lexical navigation only; not a Fortran parser or API census.
    text = re.sub(r"!.*", "", raw.decode("utf-8", errors="replace")).lower()
    modules = re.findall(r"^\s*module\s+(?!procedure\b|function\b|subroutine\b)(\w+)", text, re.M)
    names = set(re.findall(r"^\s*(?:pure\s+|elemental\s+|recursive\s+)*(?:subroutine|function)\s+(\w+)", text, re.M))
    names.update(re.findall(r"^\s*type\s*(?:,[^:\n]+)?::\s*(\w+)", text, re.M))
    imports = re.findall(r"^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)", text, re.M)
    return {"modules": sorted(set(modules)), "named_declarations": sorted(names), "use_modules": sorted(set(imports))}


ROUTES = {
    "irrigation": ("MC-IRR01 / central RT-HY / MC-CROP01", ["integration/audits/MC_IRR01_CAPABILITY_DISPOSITIONS_20261011.json", "integration/control/MC_IRR01_APPLICATION_COMPOSITION_20261011.json"]),
    "solute": ("MC-SOL01 / NUT-SOL owners PR1098 and PR1117", ["integration/audits/PPA_WU05E_STATUS.json"]),
    "macropore": ("PPA-WU05-A / MIGMAC / central runtime", ["integration/audits/PPA_WU05_MIGMAC11_STATUS.json", "integration/audits/PPA_WU05A26_STATUS.json"]),
    "frost": ("PPA-WU05-B / thermal owner", ["integration/audits/PPA_WU05B_NAN_GUARD_STATUS.json", "integration/audits/PPA_WU05B19_CANONICAL_ADMISSION.json"]),
    "oxygen": ("PPA-WU05-C / PERF03 PR1008", ["integration/audits/PPA_WU05C_OXYGEN_AUTHORITY_CONTRACT.json", "integration/audits/PPA_WU05C3A_STATUS.json"]),
    "compensated_roots": ("PPA-WU05-D / crop-root owner", ["integration/audits/PPA_WU05D_COMPENSATION_AUTHORITY_CONTRACT.json", "integration/audits/PPA_WU05D_EXACT01_STATUS.json"]),
    "salinity": ("PPA-WU05-E / crop-root and solute owners", ["integration/audits/PPA_WU05E_SALFRO01_CANONICAL_ADMISSION.json"]),
    "micro": ("PPA-WU05-G / shared hydraulics", ["integration/audits/PPA_WU05_STATUS.json"]),
    "lower_boundary": ("LOW01/03/05/08 owners / shared HY-GC", ["integration/audits/F-MIG431-LOW01A_STATUS.json", "integration/audits/F-MIG431-LOW03-A_STATUS.json", "integration/audits/F-MIG431-LOW05A_STATUS.json", "integration/audits/F-MIG431-LOW08-A_STATUS.json"]),
    "weather_interception": ("PPA-WU04 / INT12 PR1009 / MC-CROP01 / central RT-HY", ["integration/audits/PPA_WU04_STATEFUL_ET_INTERCEPTION_CONTRACT.json", "integration/audits/MC_CROP01_FILE_WEATHER_PRODUCTION_STATUS.json"]),
    "shared_solver": ("central HY / Task2 / M1 / numerical owners", ["integration/f-ci/F-CI93_STATUS.json", "docs/status-a/CURRENT_ARCHITECTURE.md"]),
    "shared_runtime": ("central RT-TX / crop-irrigation-solute owners", ["docs/status-a/CURRENT_ARCHITECTURE.md", "integration/audits/MC_CROP01_FILE_WEATHER_PRODUCTION_STATUS.json"]),
    "reconciliation": ("PPA-RECONCILE01 / central regie", ["docs/development/SWAP5_PROJECT_CONTROL.md", "integration/control/SWAP5_WORKSTREAM_REGISTRY.json"]),
}

# Domain entry points for owner review, deliberately not equivalence matches.
ENTRYPOINTS = {
    "irrigation": ["src/process/mod_scheduled_irrigation_management_policy.f90", "src/process/mod_irrigation_process.f90", "src/runtime/mod_fmr_scheduled_management_irrigation_application.f90"],
    "solute": ["src/process/mod_solute_mobile_advection_dispersion.f90", "src/process/mod_solute_macropore_exchange.f90"],
    "macropore": ["src/process/macropore/mod_ppa_wu05a6_rate_bundle.f90", "src/process/macropore/mod_macropore_standard_storage.f90", "src/runtime/mod_macropore_continuation_state.f90"],
    "frost": ["src/process/mod_frost_hydraulic_effect.f90", "src/process/mod_root_frost_stress.f90"],
    "oxygen": ["src/process/mod_root_uptake_oxygen_composition.f90", "src/physics/oxygen/mod_bartholomeus_profile_response.f90"],
    "compensated_roots": ["src/process/mod_root_uptake_compensation.f90", "src/runtime/mod_root_uptake_compensation_execution.f90"],
    "salinity": ["src/process/mod_root_salinity_response.f90"],
    "micro": ["src/process/mod_root_micro_de_willigen_process.f90", "src/runtime/mod_fmr_micro_mvg_table_binding.f90"],
    "lower_boundary": ["src/runtime/mod_fmr_legacy_bottom_boundary_application_binding.f90", "src/runtime/mod_fmr_legacy_cauchy_bottom_boundary_provider.f90", "src/runtime/mod_fmr_legacy_head_bottom_boundary_provider.f90"],
    "weather_interception": ["src/adapter/mod_swap_daily_weather_file_adapter.f90", "src/runtime/mod_fmr_crop_weather_physical_event_composition.f90", "src/runtime/mod_interception_source_window_runtime.f90"],
    "shared_solver": ["src/adapter/mod_b110_production_soil_water_task2.f90", "src/solver/mod_soil_water_solver_contract.f90", "src/adapter/mod_reference_richards_legacy_binding.f90"],
    "shared_runtime": ["src/runtime/mod_fmr_production_application_bootstrap.f90", "src/runtime/mod_fmr_serialized_reference_backend.f90", "src/runtime/mod_fmr_committed_restart.f90"],
    "reconciliation": [],
}


def family(path):
    name = path.lower()
    if "wu05f" in name or "wu05b" in name: return "frost"
    if "wu05a" in name: return "macropore"
    if "wu05c" in name: return "oxygen"
    if "wu05d" in name: return "compensated_roots"
    if "wu05e" in name: return "salinity"
    if "wu05g" in name: return "micro"
    if re.search(r"(?:ppa[_-])?irr|irrigation", name): return "irrigation"
    if re.search(r"(?:ppa[_-])sol|solute", name): return "solute"
    if re.search(r"low0[13458]", name): return "lower_boundary"
    if any(s in name for s in ("atm02", "wu04", "gash", "vonhhbraden")): return "weather_interception"
    if name.startswith("src/runtime/"): return "shared_runtime"
    if name.startswith("src/"): return "shared_solver"
    return "reconciliation"


def build(old, canonical):
    old = git("rev-parse", old).decode().strip()
    canonical = git("rev-parse", canonical).decode().strip()
    base = git("merge-base", canonical, old).decode().strip()
    changed = git("diff", "--name-only", "-z", base, old).decode().strip("\0").split("\0")
    ot, ct = tree(old), tree(canonical)
    ids = [ot[p][1] for p in changed if p in ot]
    ids += [v[1] for p, v in ct.items() if p.startswith("src/") and p.endswith(".f90")]
    raw = blobs(ids)
    by_blob, by_module, by_name = defaultdict(list), defaultdict(list), defaultdict(list)
    for p, (_, blob) in ct.items():
        by_blob[blob].append(p)
        if p.startswith("src/") and p.endswith(".f90"):
            d = declarations(raw[blob])
            for module in d["modules"]: by_module[module].append(p)
            for name in d["named_declarations"]: by_name[name].append(p)
    rows = []
    for p in changed:
        blob = ot.get(p, (None, None))[1]
        now = ct.get(p, (None, None))[1]
        state = "HISTORICAL_DELETION" if blob is None else "ABSENT_PATH" if now is None else "EXACT_PATH_BLOB" if blob == now else "DIVERGENT_PATH"
        route = family(p)
        row = {"path": p, "historical_mode": ot.get(p, (None, None))[0], "historical_blob": blob, "historical_sha256": hashlib.sha256(raw[blob]).hexdigest() if blob else None, "canonical_blob": now, "identity": state, "owner_route": route}
        if p.startswith("src/") and blob:
            d = declarations(raw[blob])
            row["historical_declarations"] = d
            row["exact_blob_locators"] = by_blob.get(blob, [])
            row["same_module_locators"] = sorted({q for m in d["modules"] for q in by_module[m]})
            anchors = defaultdict(list)
            for name in d["named_declarations"]:
                if len(by_name[name]) == 1:
                    anchors[by_name[name][0]].append(name)
            row["unique_named_declaration_locators"] = [{"path": q, "names": sorted(ns), "canonical_blob": ct[q][1]} for q, ns in sorted(anchors.items())]
        rows.append(row)
    for _, paths in ROUTES.values():
        assert all(p in ct for p in paths), paths
    for paths in ENTRYPOINTS.values():
        assert all(p in ct for p in paths), paths
    summary = {
        "paths": len(rows), "identity": dict(Counter(r["identity"] for r in rows)),
        "source_paths": sum(r["path"].startswith("src/") for r in rows),
        "source_identity": dict(Counter(r["identity"] for r in rows if r["path"].startswith("src/"))),
        "source_owner_routes": dict(Counter(r["owner_route"] for r in rows if r["path"].startswith("src/"))),
        "source_exact_blob_locators": sum(bool(r.get("exact_blob_locators")) for r in rows if r["path"].startswith("src/")),
        "source_same_module_locators": sum(bool(r.get("same_module_locators")) for r in rows if r["path"].startswith("src/")),
        "source_unique_declaration_locators": sum(bool(r.get("unique_named_declaration_locators")) for r in rows if r["path"].startswith("src/")),
    }
    report = {"schema": "swap5.ppa_reconcile01.current_lineage.v1", "work_unit": "PPA-RECONCILE01", "pr": 700, "historical_head": old, "canonical_base": canonical, "pr_merge_base": base, "summary": summary, "owner_routes": {k: {"owner": v[0], "read_only_authorities": v[1], "canonical_review_entrypoints": [{"path": p, "blob": ct[p][1]} for p in ENTRYPOINTS[k]]} for k, v in ROUTES.items()}, "scope": "Complete original PR path census and exact-byte archive; source declaration locators and routing only. No physical equivalence, current scientific qualification, capability disposition or coverage change.", "locator_limits": "Module/routine/type matches are lexical, lower-bound and not a full Fortran API parse. Domain entry points are deliberately curated review navigation, not demonstrated successors. All rows require owner decisions; absent path or empty matches do not establish absent physics.", "blocker": "Historical WU04C completed=false/committed=false; divergent shared contracts require owner decisions. Lexical matches and absent filenames cannot resolve those decisions.", "rows": rows}
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w", format=tarfile.PAX_FORMAT) as tf:
        for r in rows:
            if r["historical_blob"] is None: continue
            data = raw[r["historical_blob"]]
            info = tarfile.TarInfo("original/" + r["path"])
            info.size = len(data)
            info.mode = int(r["historical_mode"], 8) & 0o777
            tf.addfile(info, io.BytesIO(data))
        data = (json.dumps({"historical_head": old, "merge_base": base, "rows": [{k: r[k] for k in ("path", "historical_mode", "historical_blob", "historical_sha256")} for r in rows]}, indent=2) + "\n").encode()
        info = tarfile.TarInfo("MANIFEST.json")
        info.size = len(data)
        tf.addfile(info, io.BytesIO(data))
    archive = gzip.compress(buf.getvalue(), mtime=0)
    report["archive"] = {"path": "integration/audits/evidence/PPA_RECONCILE01_ORIGINAL_POSTIMAGES_20261011.tar.gz.b64", "decoded_sha256": hashlib.sha256(archive).hexdigest(), "original_postimages": sum(r["historical_blob"] is not None for r in rows), "members": sum(r["historical_blob"] is not None for r in rows) + 1}
    return report, base64.encodebytes(archive)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--historical", default="5fcd9769c30379f461ce047f410638b0d3311f96")
    ap.add_argument("--canonical", required=True)
    ap.add_argument("--output", default="integration/audits/PPA_RECONCILE01_CURRENT_LINEAGE_20261011.json")
    ap.add_argument("--verify", action="store_true")
    args = ap.parse_args()
    report, archive = build(args.historical, args.canonical)
    payload = (json.dumps(report, indent=2) + "\n").encode()
    output = Path(args.output)
    archive_path = Path(report["archive"]["path"])
    if args.verify:
        assert output.read_bytes() == payload, "Report differs from exact Git reconstruction"
        assert archive_path.read_bytes() == archive, "Archive differs from all original Git postimages"
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        archive_path.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(payload)
        archive_path.write_bytes(archive)
    print(json.dumps(report["summary"], sort_keys=True))
    print("PPA_RECONCILE01_ALL_PATHS_AND_ORIGINAL_GIT_BLOBS=" + ("VERIFIED" if args.verify else "GENERATED"))


if __name__ == "__main__":
    main()
