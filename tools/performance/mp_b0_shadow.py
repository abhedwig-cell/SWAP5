from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import zipfile
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable, Sequence

B0_DISTRIBUTION_SHA256 = "2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360"
B0_SOURCE_ARCHIVE_SHA256 = "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151"
B0_WINDOWS_EXECUTABLE_SHA256 = "d13f5e0321db1780d211520287dc59db2e7aa763649998a4b29a187195ca89a5"
B0_LINUX_EXECUTABLE_SHA256 = "e3b45c1fe66a614c1caead4b2fc0684a09165672a32d8d3bf4eac00498767862"


@dataclass(frozen=True)
class B0IdentityCheck:
    distribution_sha256: str
    source_archive_sha256: str
    windows_executable_sha256: str
    linux_executable_sha256: str

    @property
    def passed(self) -> bool:
        return (
            self.distribution_sha256 == B0_DISTRIBUTION_SHA256
            and self.source_archive_sha256 == B0_SOURCE_ARCHIVE_SHA256
            and self.windows_executable_sha256 == B0_WINDOWS_EXECUTABLE_SHA256
            and self.linux_executable_sha256 == B0_LINUX_EXECUTABLE_SHA256
        )


@dataclass(frozen=True)
class BalancePeriod:
    period: str
    storage_change_cm: float
    input_cm: float
    output_cm: float

    @property
    def residual_cm(self) -> float:
        return self.input_cm - self.output_cm - self.storage_change_cm


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: str | Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_b0_distribution(path: str | Path) -> B0IdentityCheck:
    distribution = Path(path)
    outer_hash = sha256_file(distribution)
    with zipfile.ZipFile(distribution) as archive:
        names = archive.namelist()
        source_name = _single_suffix(names, "tools/SWAP/source/SWAP.ZIP")
        windows_name = _single_suffix(names, "tools/SWAP/swap_4.3.1.exe")
        linux_name = _single_suffix(names, "tools/SWAP/swap_431")
        result = B0IdentityCheck(
            distribution_sha256=outer_hash,
            source_archive_sha256=_sha256_bytes(archive.read(source_name)),
            windows_executable_sha256=_sha256_bytes(archive.read(windows_name)),
            linux_executable_sha256=_sha256_bytes(archive.read(linux_name)),
        )
    if not result.passed:
        raise ValueError(f"distribution does not match registered B0 identity: {result}")
    return result


def _single_suffix(names: Iterable[str], suffix: str) -> str:
    matches = [name for name in names if name.replace("\\", "/").endswith(suffix)]
    if len(matches) != 1:
        raise ValueError(f"expected exactly one archive member ending in {suffix!r}, got {matches}")
    return matches[0]


def strip_intel_conditionals(
    source: str,
    *,
    defined: frozenset[str] = frozenset(),
    linux: bool = True,
) -> str:
    """Resolve the small !DEC$ conditional subset used by SWAP 4.3.1.

    This is shadow-build tooling only. It does not rewrite the immutable B0 payload.
    Unknown conditions fail rather than being guessed.
    """

    active = True
    stack: list[tuple[bool, bool]] = []
    output: list[str] = []

    for line in source.splitlines(keepends=True):
        stripped = line.strip()
        upper = stripped.upper()
        if upper.startswith("!DEC$ IF"):
            expr = stripped[len("!DEC$ IF") :].strip()
            condition = _eval_dec_condition(expr, defined=defined, linux=linux)
            stack.append((active, condition))
            active = active and condition
            continue
        if upper.startswith("!DEC$ ELSE"):
            if not stack:
                raise ValueError("!DEC$ ELSE without matching IF")
            parent, condition = stack[-1]
            stack[-1] = (parent, not condition)
            active = parent and (not condition)
            continue
        if upper.startswith("!DEC$ END IF"):
            if not stack:
                raise ValueError("!DEC$ END IF without matching IF")
            parent, _ = stack.pop()
            active = parent
            continue
        if active:
            output.append(line)

    if stack:
        raise ValueError("unterminated !DEC$ IF block")
    return "".join(output)


def _eval_dec_condition(expr: str, *, defined: frozenset[str], linux: bool) -> bool:
    compact = " ".join(expr.strip().split())
    match = re.fullmatch(r"DEFINED\s*\(\s*([A-Za-z0-9_]+)\s*\)", compact, flags=re.I)
    if match:
        return match.group(1).lower() in {name.lower() for name in defined}
    if re.fullmatch(r"\(?\s*linux\s*==\s*0\s*\)?", compact, flags=re.I):
        return not linux
    raise ValueError(f"unsupported !DEC$ condition: {expr!r}")


def instrument_swap_main(source: str) -> str:
    use_anchor = "use MOD_swap_base, only: unit_log, unit_wrn, sw_animo\n"
    dynamic_anchor = (
        "   iTask = 2\n"
        "   if (iCaller == 0) call swap(iCaller, iTask, tstart_in, tend_in)\n"
    )
    flush_anchor = "write(*,'(a)')' Swap normal completion!'\n"
    for anchor, name in (
        (use_anchor, "module use"),
        (dynamic_anchor, "dynamic call"),
        (flush_anchor, "completion write"),
    ):
        if source.count(anchor) != 1:
            raise ValueError(f"expected exactly one {name} anchor")

    source = source.replace(
        use_anchor,
        use_anchor
        + "use mp_shadow_observer, only: mp_dynamic_begin, mp_dynamic_end, mp_flush\n",
    )
    source = source.replace(
        dynamic_anchor,
        "   iTask = 2\n"
        "   call mp_dynamic_begin()\n"
        "   if (iCaller == 0) call swap(iCaller, iTask, tstart_in, tend_in)\n"
        "   call mp_dynamic_end()\n",
    )
    return source.replace(flush_anchor, "call mp_flush()\n" + flush_anchor)


def observer_fortran_source() -> str:
    return '''module mp_shadow_observer
   use iso_fortran_env, only: int64
   implicit none
   logical, save :: initialized = .false.
   logical, save :: enabled = .false.
   logical, save :: active = .false.
   integer(int64), save :: started_count = 0_int64
   integer(int64), save :: count_rate = 0_int64
   real(8), save :: dynamic_swap_seconds = 0.0d0
   integer, save :: dynamic_calls = 0
contains
   subroutine mp_init()
      character(len=32) :: value
      integer :: status
      if (initialized) return
      value = ''
      call get_environment_variable('SWAP5_MP_MEASURE', value, status=status)
      enabled = (status == 0 .and. trim(adjustl(value)) == '1')
      initialized = .true.
   end subroutine mp_init

   subroutine mp_dynamic_begin()
      call mp_init()
      if (.not. enabled) return
      call system_clock(count=started_count, count_rate=count_rate)
      if (count_rate <= 0_int64) error stop 'MP shadow clock unavailable'
      active = .true.
   end subroutine mp_dynamic_begin

   subroutine mp_dynamic_end()
      integer(int64) :: ended_count
      if (.not. enabled) return
      if (.not. active) error stop 'MP shadow span not active'
      call system_clock(count=ended_count)
      if (ended_count < started_count) error stop 'MP shadow clock moved backwards'
      dynamic_swap_seconds = dynamic_swap_seconds + &
         real(ended_count-started_count,8) / real(count_rate,8)
      dynamic_calls = dynamic_calls + 1
      active = .false.
   end subroutine mp_dynamic_end

   subroutine mp_flush()
      integer :: unitno
      call mp_init()
      if (.not. enabled) return
      if (active) error stop 'MP shadow span still active at flush'
      open(newunit=unitno, file='mp_shadow_metrics.json', status='replace', action='write')
      write(unitno,'(a,i0,a,es24.16,a)') &
         '{"schema":"mp-shadow-v1","dynamic_calls":', dynamic_calls, &
         ',"dynamic_swap_seconds":', dynamic_swap_seconds, '}'
      close(unitno)
   end subroutine mp_flush
end module mp_shadow_observer
'''


def prepare_shadow_source(source_archive: bytes, destination: str | Path) -> Path:
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(source_archive)) as archive:
        members = [name for name in archive.namelist() if name.lower().endswith(".f90")]
        if len(members) != 63:
            raise ValueError(f"expected 63 SWAP Fortran files, got {len(members)}")
        for member in members:
            target = destination / Path(member).name
            source = archive.read(member).decode("utf-8", errors="replace")
            source = strip_intel_conditionals(source, defined=frozenset(), linux=True)
            if target.name.lower() == "swap_main.f90":
                source = instrument_swap_main(source)
            target.write_text(source, encoding="utf-8")
    (destination / "mp_shadow_observer.f90").write_text(observer_fortran_source(), encoding="utf-8")
    return destination


def normalize_physical_output(text: str) -> str:
    normalized = re.sub(
        r"^\* Generated at:.*$",
        "* Generated at: <normalized>",
        text,
        flags=re.MULTILINE,
    )
    normalized = re.sub(
        r"^\* compiler version :.*$",
        "* compiler version : <normalized>",
        normalized,
        flags=re.MULTILINE,
    )
    normalized = re.sub(
        r"^\* compiler options :.*$",
        "* compiler options : <normalized>",
        normalized,
        flags=re.MULTILINE,
    )
    return normalized


def normalized_sha256(path: str | Path) -> str:
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    return _sha256_bytes(normalize_physical_output(text).encode("utf-8"))


def compare_physical_outputs(
    left: str | Path,
    right: str | Path,
    filenames: Sequence[str] = ("result.bal", "result.blc"),
) -> dict[str, bool]:
    left = Path(left)
    right = Path(right)
    return {
        name: normalized_sha256(left / name) == normalized_sha256(right / name)
        for name in filenames
    }


def parse_rounded_water_balance(text: str) -> list[BalancePeriod]:
    periods: list[BalancePeriod] = []
    chunks = re.split(r"(?=Period\s+:)", text)
    for chunk in chunks:
        if not chunk.startswith("Period"):
            continue
        period_match = re.search(r"Period\s+:\s+(.+)", chunk)
        change_match = re.search(r"Change\s+([+-]?\d+(?:\.\d+)?)\s+cm", chunk)
        if not period_match or not change_match or "Water balance components (cm)" not in chunk:
            raise ValueError("could not parse water-balance period")
        water = chunk.split("Water balance components (cm)", 1)[1]
        water = water.split("Solute balance components", 1)[0]
        sum_match = re.search(
            r"Sum\s+:?\s*([+-]?\d+(?:\.\d+)?)\s+Sum\s+:?\s*([+-]?\d+(?:\.\d+)?)",
            water,
        )
        if not sum_match:
            raise ValueError("could not parse water-balance sums")
        periods.append(
            BalancePeriod(
                period=period_match.group(1).strip(),
                storage_change_cm=float(change_match.group(1)),
                input_cm=float(sum_match.group(1)),
                output_cm=float(sum_match.group(2)),
            )
        )
    return periods


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="SWAP5 MP B0 shadow observation utility")
    sub = parser.add_subparsers(dest="command", required=True)

    verify = sub.add_parser("verify-b0", help="verify supplied SWAP 4.3.1 distribution")
    verify.add_argument("distribution", type=Path)

    compare = sub.add_parser("compare", help="compare normalized BAL/BLC outputs")
    compare.add_argument("left", type=Path)
    compare.add_argument("right", type=Path)

    balance = sub.add_parser("balance", help="report rounded annual water-balance residuals")
    balance.add_argument("bal_file", type=Path)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    if args.command == "verify-b0":
        result = verify_b0_distribution(args.distribution)
        print(json.dumps({**asdict(result), "passed": result.passed}, indent=2, sort_keys=True))
        return 0
    if args.command == "compare":
        result = compare_physical_outputs(args.left, args.right)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if all(result.values()) else 1
    if args.command == "balance":
        periods = parse_rounded_water_balance(args.bal_file.read_text(errors="replace"))
        print(json.dumps([{**asdict(p), "residual_cm": p.residual_cm} for p in periods], indent=2))
        return 0
    raise AssertionError("unreachable")


if __name__ == "__main__":
    raise SystemExit(main())
