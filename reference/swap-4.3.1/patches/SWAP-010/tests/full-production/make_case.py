#!/usr/bin/env python3
"""Generate the SWAP-010 representative full-production model-7 case.

Input must be the supplied B0 official `cases/2.grassgrowth` directory.
"""
from pathlib import Path
import argparse
import hashlib
import re
import shutil

EXPECTED_SWP_SHA256 = "d038ee57f58b100bdfaa5445b1e0ef72f06b0f26caaca5fa2f5419e4608f650e"
EXPECTED_MET_SHA256 = "48c269785405464476ca49dd315e12ae67e782fb0e6d3cd0322155d0ab8fb3bc"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("official_case", type=Path)
    ap.add_argument("output", type=Path)
    args = ap.parse_args()

    if args.output.exists():
        shutil.rmtree(args.output)
    shutil.copytree(args.official_case, args.output)

    swp = args.output / "swap.swp"
    text = swp.read_text()

    def scalar(name: str, value: str) -> None:
        nonlocal text
        pattern = rf"(?mi)^(\s*{re.escape(name)}\s*=\s*)([^!\r\n]*)(.*)$"
        text, count = re.subn(pattern, lambda m: m.group(1) + value + " " + m.group(3), text, count=1)
        if count != 1:
            raise RuntimeError(f"{name}: expected one match, got {count}")

    scalar("PROJECT", "'model7_swap010_fullrun'")
    scalar("TSTART", "1980-01-01")
    scalar("TEND", "1980-01-02")
    scalar("DATEFIX", "02 01")
    scalar("SWHEADER", "0")
    scalar("SWBAL", "1")
    scalar("SWBLC", "1")
    scalar("SWCSV", "0")

    marker = next((line for line in text.splitlines() if line.lstrip().startswith("SWHEADER =")), None)
    if marker is None:
        raise RuntimeError("SWHEADER line not found")
    text = text.replace(marker, marker + "\n  SWAFO = 2\n  CRITDEVMASBAL = 1.0E-6", 1)

    scalar("METFIL", "'m7.met'")
    scalar("SWETR", "1")
    scalar("SWDIVIDE", "0")
    scalar("SWCROP", "0")
    scalar("SWINCO", "1")

    text, count = re.subn(
        r"(?mi)^\s*GWLI\s*=.*$",
        "  HTB =\n    -0.5 -1000.0\n  -600.0 -1000.0\n* End of table",
        text,
        count=1,
    )
    if count != 1:
        raise RuntimeError("GWLI replacement failed")

    pattern = r"(?ms)^\s*ORES\s+OSAT\s+ALFA\s+NPAR\s+LEXP\s+H_ENPR\s+KSATFIT\s+KSATEXM\s+BDENS\s*\n.*?^\* End of table"
    rows = """ IHWCKMODEL ORES OSAT ALFA NPAR LEXP H_ENPR KSATFIT KSATEXM BDENS ALFA_2 NPAR_2 OMEGA_1 H0
 7 0.02 0.433878 0.003981071705535 1.15 0.5 0.0 83.24164 83.24164 1300.0 0.001995262314969 1.6 0.395652173913 -1000000.0
 7 0.02 0.433878 0.003981071705535 1.15 0.5 0.0 83.24164 83.24164 1300.0 0.001995262314969 1.6 0.395652173913 -1000000.0
 7 0.02 0.433878 0.003981071705535 1.15 0.5 0.0 83.24164 83.24164 1300.0 0.001995262314969 1.6 0.395652173913 -1000000.0
 7 0.01 0.364074 0.003981071705535 1.15 0.5 0.0 25.81471 25.81471 1300.0 0.001995262314969 1.6 0.395652173913 -1000000.0
 7 0.01 0.364074 0.003981071705535 1.15 0.5 0.0 25.81471 25.81471 1300.0 0.001995262314969 1.6 0.395652173913 -1000000.0
* End of table"""
    text, count = re.subn(pattern, rows, text, count=1)
    if count != 1:
        raise RuntimeError(f"hydraulic table: expected one match, got {count}")

    scalar("SWDRA", "0")
    scalar("SWBBCFILE", "0")
    bbc = re.search(r"(?mi)^\s*BBCFIL\s*=.*$", text)
    if bbc is None:
        raise RuntimeError("BBCFIL not found")
    text = text[:bbc.end()] + "\n\n  SWBOTB = 6                ! qualification case: zero bottom flux" + text[bbc.end():]
    scalar("SWHEA", "0")

    swp.write_text(text)
    met = args.output / "m7.met"
    met.write_text(
        "Station,DD,MM,YYYY,Rad,Tmin,Tmax,Hum,Wind,Rain,ETref,Wet\n"
        "'999',01,01,1980,18000.0,15.0,28.0,1.0,2.0,0.0,5.0,0.0\n"
        "'999',02,01,1980,18000.0,15.0,28.0,1.0,2.0,0.0,5.0,0.0\n"
    )

    print("swap.swp", sha(swp))
    print("m7.met", sha(met))
    if sha(swp) != EXPECTED_SWP_SHA256 or sha(met) != EXPECTED_MET_SHA256:
        raise SystemExit("generated case identity does not match qualified case")


if __name__ == "__main__":
    main()
