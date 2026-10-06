#!/usr/bin/env python3
"""Compile and exercise the opt-in MICRO sink through the physical backend."""
import pathlib
import re
import subprocess
import tempfile
import hashlib
import json
import os

ROOT = pathlib.Path(__file__).resolve().parents[2]
gate = (ROOT / "tests/fahl/run_fahl49_application_scale.sh").read_text()
module_block = gate.split("MODULE_SRC=(", 1)[1].split(")\n# Additive C3A", 1)[0]
sources = re.findall(r"^  (src/\S+\.f90|tests/\S+\.f90)$", module_block, re.M)
sources = subprocess.check_output(
    ["python3", "tests/support/augment_bartholomeus_backend_sources.py", *sources],
    cwd=ROOT, text=True,
).splitlines()
outputs = []
preservation_outputs = []
with tempfile.TemporaryDirectory(prefix="ppa-micro03-") as tmp:
    for opt in ("O0", "O2"):
        build = pathlib.Path(tmp) / opt
        build.mkdir()
        flags = ["-std=f2008", "-ffree-line-length-none", "-fcheck=all",
                 "-ffpe-trap=invalid,zero,overflow", f"-{opt}", f"-J{build}", f"-I{build}"]
        objects = []
        for source in [*sources, "tests/physics/test_ppa_micro03_runtime.f90"]:
            obj = build / (pathlib.Path(source).stem + ".o")
            subprocess.run(["gfortran", *flags, "-c", source, "-o", str(obj)], cwd=ROOT, check=True)
            objects.append(str(obj))
        exe = build / "test"
        subprocess.run(["gfortran", *objects, "-o", str(exe)], check=True)
        run = subprocess.run([str(exe)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        output = run.stdout
        print(output, end="", flush=True)
        run.check_returncode()
        assert "MICRO03_TRIAL_MASS_RESTART_REJECTION=PASS" in output
        assert "MICRO05_HETEROGENEOUS_APP_TRIAL=PASS" in output
        assert "MICRO06_COMMITTED_RESTART_CHANGED_FORCING=PASS" in output
        outputs.append(output)
        preservation_source = "tests/fapp/test_ppa_root_hyd01_sink_equivalence.f90"
        preservation_obj = build / "root_hyd01.o"
        subprocess.run(["gfortran", *flags, "-c", preservation_source, "-o", str(preservation_obj)],
                       cwd=ROOT, check=True)
        preservation_exe = build / "root_hyd01"
        subprocess.run(["gfortran", *objects[:-1], str(preservation_obj), "-o", str(preservation_exe)], check=True)
        preservation = subprocess.run([str(preservation_exe)], text=True,
                                      stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        preservation.check_returncode()
        assert "PPA_ROOT_HYD01_D1_SWEEP_COMPLETE=PASS" in preservation.stdout
        assert "PPA_ROOT_HYD01_D2_TEMPORAL_DIAG_COMPLETE=PASS" in preservation.stdout
        preservation_outputs.append(preservation.stdout)
        print(f"MICRO03_ROOT_HYD01_PRESERVATION_{opt}=PASS", flush=True)
assert outputs[0] == outputs[1], "O0/O2 semantic drift"
assert preservation_outputs[0] == preservation_outputs[1], "root route O0/O2 drift"
evidence_path = os.environ.get("MICRO03_RESULT")
if evidence_path:
    paths = ["src/process/mod_root_micro_matric_flux_table.f90",
             "src/process/mod_root_micro_de_willigen_process.f90",
             "src/runtime/mod_fmr_micro_mvg_table_binding.f90",
             "src/runtime/mod_fmr_serialized_reference_backend.f90",
             "src/runtime/mod_fmr_production_application_bootstrap.f90",
             "tests/physics/test_ppa_micro03_runtime.f90",
             "tests/physics/run_ppa_micro03_runtime.py",
             "tests/fapp/test_ppa_root_hyd01_sink_equivalence.f90"]
    record = {"work_unit": os.environ.get("MICRO03_EVIDENCE_WORK_UNIT", "PPA-MICRO03"),
              "status": "LOCAL_O0_O2_RUNTIME_PASS",
              "source_sha256": {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths},
              "gfortran": subprocess.check_output(["gfortran", "--version"], text=True).splitlines()[0],
              "outputs": {"O0": outputs[0].splitlines(), "O2": outputs[1].splitlines()},
              "preservation_outputs": {"O0": preservation_outputs[0].splitlines(),
                                       "O2": preservation_outputs[1].splitlines()}}
    pathlib.Path(evidence_path).write_text(json.dumps(record, indent=2) + "\n")
print("MICRO03_LOCAL_O0_O2=PASS")
