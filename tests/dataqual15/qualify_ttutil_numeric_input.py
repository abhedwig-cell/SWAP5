"""Check the original TTUTIL OSAT conversion with production input flags."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/solute"))
from legacy_reader_sources import materialize, original_input_compile_flags

DRIVER = """program original_osat
  use iso_fortran_env, only: int64, real64
  implicit none
  character(4096) :: filename
  character(16) :: decimal_text
  real(real64) :: values(100), internal_value
  integer :: count

  call get_command_argument(1, filename)
  call rdinit(20, 0, trim(filename))
  call rdfdor('OSAT', 0.0_real64, 1.0_real64, values, 100, count)
  if (count /= 8) error stop 'Original Andelst OSAT count'
  decimal_text = '0.393'
  read(decimal_text, *) internal_value
  write(*,'(A,*(Z16.16,1X))') 'TTUTIL_OSAT_BITS=', transfer(values(:count), [0_int64])
  write(*,'(A,Z16.16)') 'INTERNAL_0393_BITS=', transfer(internal_value, 0_int64)
  if (transfer(values(3),0_int64) /= transfer(internal_value,0_int64)) &
      error stop 'Original OSAT differs from correctly rounded 0.393'
  close(20)
  print '(A)', 'TTUTIL_ORIGINAL_OSAT_BITS=PASS'
end program original_osat
"""


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def execute(command, folder, category, events, timeout):
    command = list(map(str, command))
    started = time.monotonic()
    try:
        result = subprocess.run(command, cwd=folder, capture_output=True, timeout=timeout)
        stdout, stderr, returncode = result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired as error:
        stdout, stderr, returncode = error.stdout or b"", error.stderr or b"", None
    index = len(events)
    (folder / f"{index}.stdout").write_bytes(stdout)
    (folder / f"{index}.stderr").write_bytes(stderr)
    events.append({
        "command": command,
        "category": category,
        "returncode": returncode,
        "seconds": time.monotonic() - started,
    })
    (folder / "events.json").write_text(json.dumps(events, indent=2) + "\n")
    if returncode != 0:
        raise RuntimeError(f"{category} returned {returncode}: " +
                           stdout.decode(errors="replace") + stderr.decode(errors="replace"))
    return stdout.decode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    compiler = args.compiler.resolve()
    sources = output / "sources"
    sources.mkdir()
    _, providers = materialize(ROOT, sources)
    original = ROOT / "reference/swap-4.3.1/projects/3.macroporeflow/swap.swp"
    authority = ROOT / "integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64"
    archive_bytes = base64.b64decode(authority.read_bytes())
    profiles = {}
    for optimization in ("O0", "O2"):
        folder = output / optimization
        folder.mkdir()
        events = []
        flags = [
            "-" + optimization, "-std=legacy", "-fallow-argument-mismatch",
            "-ffree-line-length-none", "-ffixed-line-length-none", "-fcheck=all",
            "-fbacktrace", "-ffpe-trap=invalid,zero,overflow",
            "-I" + str(folder), "-J" + str(folder),
        ]
        objects = []
        reader_flags = None
        for index, source in enumerate(providers):
            obj = folder / f"{index}.o"
            selected = original_input_compile_flags(flags, source)
            execute([compiler, *selected, "-c", source, "-o", obj],
                    folder, "compile", events, 60)
            objects.append(obj)
            if source.stem.lower() == "rdlex":
                reader_flags = selected
        archive = folder / "libttutil.a"
        archiver = subprocess.check_output(
            [compiler, "-print-prog-name=ar"], text=True).strip()
        execute([archiver, "rcs", archive, *objects], folder, "archive", events, 30)
        driver = folder / "original_osat.f90"
        driver.write_text(DRIVER)
        executable = folder / ("original_osat.exe" if os.name == "nt" else "original_osat")
        execute([compiler, "-" + optimization, "-std=f2008", driver, archive, "-o", executable],
                folder, "link", events, 30)
        stdout = execute([executable, original], folder, "native", events, 15)
        assert "TTUTIL_ORIGINAL_OSAT_BITS=PASS" in stdout
        bits = next(line.split("=", 1)[1].split() for line in stdout.splitlines()
                    if line.startswith("TTUTIL_OSAT_BITS="))
        profiles[optimization] = {
            "osat_bits": bits,
            "reader_flags": reader_flags,
            "archive_sha256": digest(archive),
            "executable_sha256": digest(executable),
            "source_count": len(providers),
            "cost_seconds": {
                category: sum(event["seconds"] for event in events
                              if event["category"] == category)
                for category in ("compile", "archive", "link", "native")
            },
        }
    assert profiles["O0"]["osat_bits"] == profiles["O2"]["osat_bits"]
    result = {
        "status": "TTUTIL_ORIGINAL_OSAT_O0_O2_BITS_PASS",
        "candidate": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "compiler": subprocess.check_output([compiler, "--version"], text=True).splitlines()[0],
        "authority_zip_sha256": hashlib.sha256(archive_bytes).hexdigest(),
        "original_input_sha256": digest(original),
        "flag_provider_sha256": digest(ROOT / "tools/solute/legacy_reader_sources.py"),
        "driver_sha256": hashlib.sha256(DRIVER.encode()).hexdigest(),
        "profiles": profiles,
    }
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    print(result["status"])


if __name__ == "__main__":
    main()
