"""Focused O0/O2 standalone and real MvG-table smoke; not source equivalence."""
import hashlib
import json
import os
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCES = [
    "src/solver/mod_soil_water_solver_contract.f90",
    "src/solver/mod_b110_default_mvg_provider.f90",
    "src/process/mod_root_micro_matric_flux_table.f90",
    "src/process/mod_root_micro_de_willigen_process.f90",
    "src/runtime/mod_fmr_micro_mvg_table_binding.f90",
    "tests/physics/test_ppa_micro02_de_willigen.f90",
]
outputs = {}
with tempfile.TemporaryDirectory(prefix="micro02-dw-") as tmp:
    tmp = pathlib.Path(tmp)
    for opt in ("O0", "O2"):
        build = tmp / opt
        build.mkdir()
        binary = build / "test"
        subprocess.run(["gfortran", "-" + opt, "-std=f2008", "-ffree-line-length-none",
                        "-Wall", "-Wextra", "-fcheck=all",
                        "-ffpe-trap=invalid,zero,overflow", "-J" + str(build), "-I" + str(build),
                        *(str(ROOT / p) for p in SOURCES), "-o", str(binary)],
                       cwd=build, check=True)
        outputs[opt] = subprocess.check_output([str(binary)], text=True, cwd=build)
        print(outputs[opt], end="")
assert outputs["O0"] == outputs["O2"]
print("MICRO02_O0_O2_IDENTICAL=PASS")
if os.environ.get("MICRO02_RESULT"):
    pathlib.Path(os.environ["MICRO02_RESULT"]).write_text(json.dumps({
        "schema": "swap5.micro02.standalone_smoke.v1",
        "postimage": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "source_sha256": {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in SOURCES},
        "runs": outputs,
        "claim_ceiling": "Standalone smoke and real MvG provider only; no exact source oracle or runtime admission",
    }, indent=2) + "\n")
