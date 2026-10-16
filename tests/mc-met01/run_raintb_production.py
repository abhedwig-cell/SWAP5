#!/usr/bin/env python3
"""Reuse the exact crop/weather compilation fixture for an isolated boundary probe."""
from pathlib import Path
import hashlib
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PINS = {
    "tests/fmig431/run_crop_file_weather_production.sh": "b4cfeedb9a09339ef095005243168978d1376956",
    "tests/fmig431/test_crop_file_weather_production.f90": "5350f175cccda6f01c9812afb7c231a1cb118cc8",
}


def main():
    for path, expected in PINS.items():
        raw = (ROOT / path).read_bytes()
        actual = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
        assert actual == expected, (path, actual, expected)
    source = (ROOT / "tests/fmig431/test_crop_file_weather_production.f90").read_text()
    first = source.index("  call test_rooted_weather_production()")
    boundary = source.index("\ncontains\n")
    source = source[:first] + "  call test_raintb_production()\n" + source[boundary:]
    body = (ROOT / "tests/mc-met01/test_raintb_production.inc").read_text()
    source = source.replace("\ncontains\n", "\ncontains\n" + body, 1)
    runner = (ROOT / "tests/fmig431/run_crop_file_weather_production.sh").read_text()
    # Preserve original authentic weather extraction, literal source oracles,
    # geometry, module order, compiler flags and O0/O2. Only execute our probe.
    runner = runner.split("    for moisture in neutral dry hydraulic; do", 1)[0]
    runner += '''    for mode in continuous restart; do
      ./test "$BUILD/weather.999" "$BUILD/altered.999" "$BUILD/bad.999" "$BUILD/backup.999" "$mode" neutral > "$mode.txt"
    done
    cmp continuous.txt restart.txt
    cp continuous.txt output.txt
  )
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo 'MC_MET01_ACTUAL_RAINTB_PRODUCTION_O0_O2=PASS'
'''
    with tempfile.TemporaryDirectory(prefix="mc-met01-raintb-") as directory:
        temporary = Path(directory)
        driver = temporary / "driver.f90"
        driver.write_text(source)
        original = 'ROOT="$(cd "$(dirname "$0")/../.." && pwd)"'
        assert runner.count(original) == 1
        runner = runner.replace(original, 'ROOT="$MC_MET01_PROBE_ROOT"')
        original = '"$ROOT/tests/fmig431/test_crop_file_weather_production.f90"'
        assert runner.count(original) == 1
        runner = runner.replace(original, '"$MC_MET01_PROBE_DRIVER"')
        shell = temporary / "run.sh"
        shell.write_text(runner)
        environment = dict(os.environ, MC_MET01_PROBE_ROOT=str(ROOT), MC_MET01_PROBE_DRIVER=str(driver))
        subprocess.run(["bash", str(shell)], env=environment, check=True, cwd=ROOT)


if __name__ == "__main__":
    main()
