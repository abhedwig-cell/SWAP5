from __future__ import annotations

import argparse
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

SCHEMA_VERSION = "mp-repeatability-samples-v1"


def read_jsonl(path: str | Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with Path(path).open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            text = line.strip()
            if not text:
                continue
            try:
                row = json.loads(text)
            except json.JSONDecodeError as exc:
                raise ValueError(f"invalid JSON on line {line_number}: {exc}") from exc
            rows.append(row)
    return rows


def rotating_schedule(variants: Sequence[str], cycles: int) -> list[tuple[int, str]]:
    if cycles < 1:
        raise ValueError("cycles must be >= 1")
    if len(variants) < 2 or len(set(variants)) != len(variants):
        raise ValueError("variants must contain at least two unique names")
    schedule: list[tuple[int, str]] = []
    for cycle in range(cycles):
        offset = cycle % len(variants)
        order = list(variants[offset:]) + list(variants[:offset])
        schedule.extend((cycle, name) for name in order)
    return schedule


def _distribution(
    values: Sequence[float], *, include_cv: bool = True
) -> dict[str, float | int]:
    if not values:
        raise ValueError("distribution requires at least one value")
    values = [float(value) for value in values]
    mean = statistics.fmean(values)
    stdev = statistics.stdev(values) if len(values) > 1 else 0.0
    result: dict[str, float | int] = {
        "n": len(values),
        "mean": mean,
        "median": statistics.median(values),
        "stdev": stdev,
        "min": min(values),
        "max": max(values),
    }
    if include_cv:
        result["cv"] = 0.0 if mean == 0.0 else stdev / mean
    return result


def validate_samples(rows: Iterable[Mapping[str, Any]]) -> list[str]:
    errors: list[str] = []
    seen: set[tuple[int, str]] = set()
    hashes_by_output: dict[str, set[str]] = defaultdict(set)
    for index, row in enumerate(rows):
        where = f"rows[{index}]"
        if row.get("schema_version") != SCHEMA_VERSION:
            errors.append(f"{where}.schema_version must be {SCHEMA_VERSION}")
        cycle = row.get("cycle")
        variant = row.get("variant")
        wall = row.get("wall_seconds")
        if not isinstance(cycle, int) or cycle < 0:
            errors.append(f"{where}.cycle must be a non-negative integer")
        if not isinstance(variant, str) or not variant:
            errors.append(f"{where}.variant must be non-empty")
        if (
            not isinstance(wall, (int, float))
            or not math.isfinite(float(wall))
            or wall <= 0
        ):
            errors.append(f"{where}.wall_seconds must be finite and > 0")
        if isinstance(cycle, int) and isinstance(variant, str):
            key = (cycle, variant)
            if key in seen:
                errors.append(f"duplicate cycle/variant sample: {key}")
            seen.add(key)
        hashes = row.get("hashes")
        if not isinstance(hashes, Mapping) or not hashes:
            errors.append(f"{where}.hashes must be non-empty")
        else:
            for name, digest in hashes.items():
                if (
                    not isinstance(name, str)
                    or not isinstance(digest, str)
                    or len(digest) != 64
                ):
                    errors.append(f"{where}.hashes contains invalid SHA-256 entry")
                else:
                    hashes_by_output[name].add(digest)
    for name, digests in sorted(hashes_by_output.items()):
        if len(digests) != 1:
            errors.append(f"physical output hash changed across samples: {name}")
    return errors


def summarize_samples(
    rows: Iterable[Mapping[str, Any]],
    *,
    baseline_variant: str,
    measured_variant: str,
) -> dict[str, Any]:
    samples = [dict(row) for row in rows]
    errors = validate_samples(samples)
    if errors:
        raise ValueError("; ".join(errors))

    by_variant: dict[str, list[float]] = defaultdict(list)
    by_cycle: dict[int, dict[str, float]] = defaultdict(dict)
    output_hashes: dict[str, str] = {}
    internal_dynamic: list[float] = []

    for row in samples:
        variant = str(row["variant"])
        cycle = int(row["cycle"])
        wall = float(row["wall_seconds"])
        by_variant[variant].append(wall)
        by_cycle[cycle][variant] = wall
        for name, digest in row["hashes"].items():
            output_hashes[str(name)] = str(digest)
        internal = row.get("internal_dynamic_seconds")
        if variant == measured_variant and internal is not None:
            value = float(internal)
            if not math.isfinite(value) or value <= 0:
                raise ValueError("internal_dynamic_seconds must be finite and > 0")
            internal_dynamic.append(value)

    if baseline_variant not in by_variant or measured_variant not in by_variant:
        raise ValueError("baseline and measured variants must both be present")

    paired: list[float] = []
    incomplete_cycles: list[int] = []
    for cycle in sorted(by_cycle):
        row = by_cycle[cycle]
        if baseline_variant not in row or measured_variant not in row:
            incomplete_cycles.append(cycle)
            continue
        paired.append(row[measured_variant] / row[baseline_variant] - 1.0)
    if incomplete_cycles:
        raise ValueError(f"missing paired variants in cycles: {incomplete_cycles}")

    paired_dist = _distribution(paired, include_cv=False)
    paired_stdev = float(paired_dist["stdev"])
    paired_n = int(paired_dist["n"])
    two_se = 0.0 if paired_n < 2 else 2.0 * paired_stdev / math.sqrt(paired_n)

    result: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "sample_count": len(samples),
        "cycle_count": len(by_cycle),
        "variants": {
            key: _distribution(values) for key, values in sorted(by_variant.items())
        },
        "paired_comparison": {
            "baseline_variant": baseline_variant,
            "measured_variant": measured_variant,
            "relative_delta": paired_dist,
            "two_standard_error_scale": two_se,
            "resolved_above_two_se": abs(float(paired_dist["mean"])) > two_se,
        },
        "physical_output_hashes": dict(sorted(output_hashes.items())),
    }
    if internal_dynamic:
        result["measured_internal_dynamic_seconds"] = _distribution(internal_dynamic)
    return result


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Summarize paired SWAP5 MP repeatability samples"
    )
    parser.add_argument("samples", type=Path)
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--measured", required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    summary = summarize_samples(
        read_jsonl(args.samples),
        baseline_variant=args.baseline,
        measured_variant=args.measured,
    )
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
