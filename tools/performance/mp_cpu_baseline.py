from __future__ import annotations

import argparse
import json
import math
import os
import platform
import statistics
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

SAMPLE_SCHEMA_VERSION = "mp-cpu-baseline-samples-v1"
SUMMARY_SCHEMA_VERSION = "mp-cpu-baseline-summary-v1"
PLAN_SCHEMA_VERSION = "mp-cpu-baseline-plan-v1"


def read_jsonl(path: str | Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with Path(path).open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            text = line.strip()
            if not text:
                continue
            try:
                rows.append(json.loads(text))
            except json.JSONDecodeError as exc:
                raise ValueError(f"invalid JSON on line {line_number}: {exc}") from exc
    return rows


def required_pair_count(pilot_stdev: float, target_resolution: float, multiplier: float = 2.0) -> int:
    for name, value in (("pilot_stdev", pilot_stdev), ("target_resolution", target_resolution), ("multiplier", multiplier)):
        if not isinstance(value, (int, float)) or not math.isfinite(float(value)) or value <= 0:
            raise ValueError(f"{name} must be finite and > 0")
    return max(2, math.ceil((float(multiplier) * float(pilot_stdev) / float(target_resolution)) ** 2))


def _cpu_model() -> str | None:
    try:
        for line in Path("/proc/cpuinfo").read_text(errors="replace").splitlines():
            if line.lower().startswith("model name") and ":" in line:
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return None


def _governors() -> list[str]:
    values: set[str] = set()
    for path in Path("/sys/devices/system/cpu").glob("cpu*/cpufreq/scaling_governor"):
        try:
            values.add(path.read_text().strip())
        except OSError:
            pass
    return sorted(value for value in values if value)


def host_snapshot() -> dict[str, Any]:
    affinity: list[int] | None = None
    if hasattr(os, "sched_getaffinity"):
        affinity = sorted(os.sched_getaffinity(0))
    loadavg: list[float] | None = None
    try:
        loadavg = list(os.getloadavg())
    except (AttributeError, OSError):
        pass
    return {
        "platform": platform.platform(),
        "machine": platform.machine(),
        "cpu_model": _cpu_model(),
        "logical_cpu_count": os.cpu_count(),
        "process_affinity_cpus": affinity,
        "loadavg_1_5_15": loadavg,
        "frequency_governors": _governors(),
    }


def validate_plan(plan: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    if plan.get("schema_version") != PLAN_SCHEMA_VERSION:
        errors.append(f"schema_version must be {PLAN_SCHEMA_VERSION}")
    if plan.get("primary_metric") != "child_cpu_seconds":
        errors.append("primary_metric must be child_cpu_seconds")
    if plan.get("secondary_metric") != "wall_elapsed_seconds":
        errors.append("secondary_metric must be wall_elapsed_seconds")
    target = plan.get("target_resolution_relative")
    mult = plan.get("resolution_multiplier")
    pilot = plan.get("pilot_paired_stdev")
    pairs = plan.get("predeclared_pairs")
    try:
        expected = required_pair_count(float(pilot), float(target), float(mult))
    except (TypeError, ValueError):
        errors.append("pilot/target/multiplier must be finite and > 0")
    else:
        if pairs != expected:
            errors.append(f"predeclared_pairs must equal pilot-derived requirement {expected}")
    affinity = plan.get("affinity", {})
    cpus = affinity.get("target_cpus") if isinstance(affinity, Mapping) else None
    if not isinstance(cpus, list) or not cpus or any(not isinstance(cpu, int) or cpu < 0 for cpu in cpus):
        errors.append("affinity.target_cpus must be a non-empty list of non-negative integers")
    if len(set(cpus or [])) != len(cpus or []):
        errors.append("affinity.target_cpus must be unique")
    warmup = plan.get("warmup_runs_per_variant")
    if not isinstance(warmup, int) or warmup < 1:
        errors.append("warmup_runs_per_variant must be an integer >= 1")
    expected_exit = plan.get("expected_exit_code")
    if not isinstance(expected_exit, int):
        errors.append("expected_exit_code must be an integer")
    outputs = plan.get("physical_outputs")
    if not isinstance(outputs, list) or not outputs or any(not isinstance(name, str) or not name for name in outputs):
        errors.append("physical_outputs must be a non-empty string list")
    variants = plan.get("variants")
    if not isinstance(variants, Mapping) or len(variants) != 2:
        errors.append("variants must contain exactly two variant definitions")
    else:
        for name, spec in variants.items():
            if not isinstance(name, str) or not name or not isinstance(spec, Mapping):
                errors.append("variant names/specifications must be non-empty strings/objects")
                continue
            env = spec.get("environment")
            if not isinstance(env, Mapping):
                errors.append(f"variants.{name}.environment must be an object")
    executable_sha = plan.get("executable_sha256")
    if executable_sha is not None and (not isinstance(executable_sha, str) or len(executable_sha) != 64):
        errors.append("executable_sha256 must be a SHA-256 hex string")
    return errors


def validate_samples(rows: Iterable[Mapping[str, Any]], *, baseline_variant: str, measured_variant: str) -> list[str]:
    errors: list[str] = []
    samples = list(rows)
    seen: set[tuple[int, str]] = set()
    hashes: dict[str, set[str]] = {}
    affinities: set[tuple[int, ...]] = set()
    variants = {baseline_variant, measured_variant}
    for index, row in enumerate(samples):
        where = f"rows[{index}]"
        if row.get("schema_version") != SAMPLE_SCHEMA_VERSION:
            errors.append(f"{where}.schema_version must be {SAMPLE_SCHEMA_VERSION}")
        cycle = row.get("cycle")
        variant = row.get("variant")
        if not isinstance(cycle, int) or cycle < 0:
            errors.append(f"{where}.cycle must be a non-negative integer")
        if variant not in variants:
            errors.append(f"{where}.variant must be one of {sorted(variants)}")
        if isinstance(cycle, int) and isinstance(variant, str):
            key = (cycle, variant)
            if key in seen:
                errors.append(f"duplicate cycle/variant sample: {key}")
            seen.add(key)
        for metric in ("child_cpu_seconds", "wall_elapsed_seconds"):
            value = row.get(metric)
            if not isinstance(value, (int, float)) or not math.isfinite(float(value)) or value <= 0:
                errors.append(f"{where}.{metric} must be finite and > 0")
        affinity = row.get("target_affinity_cpus")
        if not isinstance(affinity, list) or not affinity or any(not isinstance(cpu, int) or cpu < 0 for cpu in affinity):
            errors.append(f"{where}.target_affinity_cpus must be non-empty integer list")
        else:
            affinities.add(tuple(affinity))
        row_hashes = row.get("hashes")
        if not isinstance(row_hashes, Mapping) or not row_hashes:
            errors.append(f"{where}.hashes must be non-empty")
        else:
            for name, digest in row_hashes.items():
                if not isinstance(name, str) or not isinstance(digest, str) or len(digest) != 64:
                    errors.append(f"{where}.hashes contains invalid SHA-256 entry")
                else:
                    hashes.setdefault(name, set()).add(digest)
    if len(affinities) > 1:
        errors.append("target CPU affinity changed across samples")
    for name, digests in sorted(hashes.items()):
        if len(digests) != 1:
            errors.append(f"physical output hash changed across samples: {name}")
    by_cycle: dict[int, set[str]] = {}
    for row in samples:
        if isinstance(row.get("cycle"), int) and isinstance(row.get("variant"), str):
            by_cycle.setdefault(int(row["cycle"]), set()).add(str(row["variant"]))
    incomplete = sorted(cycle for cycle, got in by_cycle.items() if got != variants)
    if incomplete:
        errors.append(f"incomplete paired cycles: {incomplete}")
    return errors


def _distribution(values: Sequence[float]) -> dict[str, float | int]:
    if not values:
        raise ValueError("distribution requires at least one value")
    values = [float(v) for v in values]
    return {
        "n": len(values),
        "mean": statistics.fmean(values),
        "median": statistics.median(values),
        "stdev": statistics.stdev(values) if len(values) > 1 else 0.0,
        "min": min(values),
        "max": max(values),
    }


def summarize_samples(
    rows: Iterable[Mapping[str, Any]], *, baseline_variant: str, measured_variant: str,
    target_resolution_relative: float, resolution_multiplier: float = 2.0,
) -> dict[str, Any]:
    samples = [dict(row) for row in rows]
    errors = validate_samples(samples, baseline_variant=baseline_variant, measured_variant=measured_variant)
    if errors:
        raise ValueError("; ".join(errors))
    if target_resolution_relative <= 0 or resolution_multiplier <= 0:
        raise ValueError("target resolution and multiplier must be > 0")
    by_cycle: dict[int, dict[str, Mapping[str, Any]]] = {}
    output_hashes: dict[str, str] = {}
    for row in samples:
        by_cycle.setdefault(int(row["cycle"]), {})[str(row["variant"])] = row
        for name, digest in row["hashes"].items():
            output_hashes[str(name)] = str(digest)
    metrics: dict[str, Any] = {}
    for metric in ("child_cpu_seconds", "wall_elapsed_seconds"):
        deltas = [
            float(pair[measured_variant][metric]) / float(pair[baseline_variant][metric]) - 1.0
            for _, pair in sorted(by_cycle.items())
        ]
        dist = _distribution(deltas)
        n = int(dist["n"])
        stdev = float(dist["stdev"])
        floor = 0.0 if n < 2 else resolution_multiplier * stdev / math.sqrt(n)
        metrics[metric] = {
            "relative_delta": dist,
            "resolution_multiplier": resolution_multiplier,
            "minimum_detectable_relative_effect": floor,
            "target_resolution_relative": target_resolution_relative,
            "target_resolution_qualified": floor <= target_resolution_relative,
            "observed_effect_resolved": abs(float(dist["mean"])) > floor,
        }
    primary = metrics["child_cpu_seconds"]
    affinities = sorted({tuple(row["target_affinity_cpus"]) for row in samples})
    return {
        "schema_version": SUMMARY_SCHEMA_VERSION,
        "sample_count": len(samples),
        "pair_count": len(by_cycle),
        "baseline_variant": baseline_variant,
        "measured_variant": measured_variant,
        "primary_metric": "child_cpu_seconds",
        "secondary_metric": "wall_elapsed_seconds",
        "target_affinity_cpus": list(affinities[0]),
        "metrics": metrics,
        "physical_output_hashes": dict(sorted(output_hashes.items())),
        "production_baseline_resolution_qualified": bool(primary["target_resolution_qualified"]),
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="SWAP5 MP controlled CPU baseline utilities")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("probe")
    plan = sub.add_parser("validate-plan")
    plan.add_argument("plan", type=Path)
    rec = sub.add_parser("recommend-pairs")
    rec.add_argument("--pilot-stdev", type=float, required=True)
    rec.add_argument("--target-resolution", type=float, required=True)
    rec.add_argument("--multiplier", type=float, default=2.0)
    summ = sub.add_parser("summarize")
    summ.add_argument("samples", type=Path)
    summ.add_argument("--baseline", required=True)
    summ.add_argument("--measured", required=True)
    summ.add_argument("--target-resolution", type=float, required=True)
    summ.add_argument("--multiplier", type=float, default=2.0)
    args = parser.parse_args(argv)
    if args.command == "probe":
        print(json.dumps(host_snapshot(), indent=2, sort_keys=True)); return 0
    if args.command == "validate-plan":
        payload = json.loads(args.plan.read_text())
        errors = validate_plan(payload)
        print(json.dumps({"valid": not errors, "errors": errors}, indent=2, sort_keys=True)); return 0 if not errors else 1
    if args.command == "recommend-pairs":
        print(required_pair_count(args.pilot_stdev, args.target_resolution, args.multiplier)); return 0
    if args.command == "summarize":
        result = summarize_samples(read_jsonl(args.samples), baseline_variant=args.baseline,
            measured_variant=args.measured, target_resolution_relative=args.target_resolution,
            resolution_multiplier=args.multiplier)
        print(json.dumps(result, indent=2, sort_keys=True)); return 0
    raise AssertionError("unreachable")


if __name__ == "__main__":
    raise SystemExit(main())
