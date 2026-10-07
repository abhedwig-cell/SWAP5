"""Collect completed local reconciliation runs, without assigning admission."""
import gzip
import csv
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tests/qualification/ppa-wu05-migmac10-canonical-20261006"
OUT.mkdir(exist_ok=True)
source = subprocess.check_output(["git", "rev-parse", "HEAD:src"], cwd=ROOT, text=True).strip()
assert source == "711a1a4b4a2dbcd737472c819519a01a3ffc7571"
gates = {
    "restart": "PPA_WU05_MIGMAC10_BOESTEN_MACROPORE_O0_O2_IDENTITY=PASS",
    "frost": "MIGMAC10_B19_24_CASES_O0_O2_IDENTITY=PASS",
    "boesten": "PPA-WU04-B BOESTEN PRESERVATION PASS",
    "a10": "PPA_WU05_MIGMAC07_PARTIAL_A10_O0_O2=PASS",
    "migmac09": "PPA_WU05_MIGMAC09_NONRIGID_COVER_O0_O2=PASS",
    "perch20": "PPA_WU05_PERCH20_O0_O2_IDENTITY=PASS",
}
receipts = []
for name, marker in gates.items():
    data = Path(f"/tmp/migmac10-canonical-{name}.log").read_bytes()
    assert marker.encode() in data
    (OUT / f"{name}.log.gz").write_bytes(gzip.compress(data, mtime=0))
    receipts.append(dict(gate=name, terminal_marker=marker, sha256=hashlib.sha256(data).hexdigest()))
frost = Path("/tmp/ppa-wu05b19-low-air-runtime-migmac10-reconciled")
frost_raw = {str(p.relative_to(frost)): p.read_text() for p in frost.glob("o*/migmac10-case-*.*")}
assert len(list(frost.glob("o*/migmac10-case-*.json"))) == 48
(OUT / "frost-raw.json.gz").write_bytes(gzip.compress(json.dumps(frost_raw).encode(), mtime=0))

run = Path("/tmp/migmac10-b111-verified")
assert (run / "case/swap.ok").exists()
error_file = run / "case/swap.err"
assert not error_file.exists() or not error_file.read_text().strip()
assert b"1999-04-26" in (run / "case/result_output.csv").read_bytes()
source_roots = [("B1.11", Path("/workspace/scratch/5560a6e2d147/authority/B111/SWAP")),
                ("TTUTIL", Path("/workspace/scratch/182eb98ca806/recovery/reference-source/TTUTIL"))]
counts = {}
for family, directory in source_roots:
    rows = (ROOT / f"tests/data/ppa_wu05_migmac01/{family}-source-manifest.sha256").read_text().splitlines()
    for row in rows:
        digest, size, name = row.split()
        path = directory / (Path(name).name if family == "B1.11" else name)
        data = path.read_bytes()
        assert len(data) == int(size) and hashlib.sha256(data).hexdigest() == digest
    counts[family] = len(rows)
names = ["swap.swp", "swap.bbc", "swap.dra", "wintcer1.crp", "wintcer2.crp",
         "andelst_meteo.998", "andelst_meteo.999", "andelst_rain.998", "andelst_rain.999",
         "result_output.csv", "swap.ok", "swap.err", "macrogeom.csv", "soilshrinkchar.csv"]
files = {}
for name in names:
    if name == "swap.err" and not error_file.exists():
        files[name] = dict(present=False, error=False)
        continue
    data = (run / "case" / name).read_bytes()
    files[name] = dict(sha256=hashlib.sha256(data).hexdigest(), bytes=len(data))
    (OUT / ("b111-" + name + ".gz")).write_bytes(gzip.compress(data, mtime=0))
report = dict(source_tree=source, canonical="78acf56f931763d2e1d4924b3dea0742f231d2e8",
              gates=receipts, b111_manifest_counts=counts, b111_files=files,
              executable_sha256=hashlib.sha256((run / "reference-run/swap_b111").read_bytes()).hexdigest(),
              compiler=subprocess.check_output(["gfortran", "--version"], text=True).splitlines()[0],
              source_runner="tools/vq/migmac01_build_reference.py",
              reference_exit_code=100,
              qualification_scope="Bounded merged composition and preservation; B1.11 full-case reference only",
              production_admitted=False, swap5_full_case_equivalent=False)
b0 = Path('/tmp/migmac10-b0-andelst-fullcsv-20261006/run/3.macroporeflow/result_output.csv').read_bytes()
b1 = (run / 'case/result_output.csv').read_bytes()
rows0 = list(csv.DictReader(b0.decode().splitlines()[6:]))
rows1 = list(csv.DictReader(b1.decode().splitlines()[6:]))
assert len(rows0) == len(rows1) == 482 and rows0 == rows1
(OUT / 'b0-comparison-output.csv.gz').write_bytes(gzip.compress(b0, mtime=0))
report['b0_b111_comparison'] = dict(records=482, fields=['DATE', 'RAIN', 'DRN', 'GWL'],
                                  exact=True, b0_sha256=hashlib.sha256(b0).hexdigest(),
                                  scope='Only the four emitted fields, not all state or physics')
(OUT / "reconciliation.json").write_text(json.dumps(report, indent=2) + "\n")
print("MIGMAC10_RECONCILIATION_EVIDENCE=PASS")
