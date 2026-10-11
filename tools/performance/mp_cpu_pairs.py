from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Mapping, Sequence

from tools.performance.mp_cpu_baseline import SAMPLE_SCHEMA_VERSION, summarize_samples

PAIR_SCHEMA_VERSION = "mp-cpu-baseline-pairs-v1"


def pairs_to_samples(payload: Mapping[str, Any]) -> list[dict[str, Any]]:
    if payload.get("schema_version") != PAIR_SCHEMA_VERSION:
        raise ValueError(f"schema_version must be {PAIR_SCHEMA_VERSION}")
    affinity = payload.get("target_affinity_cpus")
    hashes = payload.get("physical_output_hashes")
    pairs = payload.get("pairs")
    if not isinstance(affinity, list) or not affinity:
        raise ValueError("target_affinity_cpus must be non-empty")
    if not isinstance(hashes, Mapping) or not hashes:
        raise ValueError("physical_output_hashes must be non-empty")
    if not isinstance(pairs, list) or not pairs:
        raise ValueError("pairs must be non-empty")
    samples: list[dict[str, Any]] = []
    seen: set[int] = set()
    for pair in pairs:
        if not isinstance(pair, Mapping):
            raise ValueError("each pair must be an object")
        cycle = pair.get("cycle")
        if not isinstance(cycle, int) or cycle < 0 or cycle in seen:
            raise ValueError("pair cycles must be unique non-negative integers")
        seen.add(cycle)
        for variant in ("off", "on"):
            samples.append({
                "schema_version": SAMPLE_SCHEMA_VERSION,
                "cycle": cycle,
                "variant": variant,
                "child_cpu_seconds": pair[f"{variant}_child_cpu_seconds"],
                "wall_elapsed_seconds": pair[f"{variant}_wall_elapsed_seconds"],
                "target_affinity_cpus": list(affinity),
                "hashes": dict(hashes),
            })
    return samples


def summarize_paired_file(
    path: str | Path, *, target_resolution_relative: float, resolution_multiplier: float = 2.0
) -> dict[str, Any]:
    payload = json.loads(Path(path).read_text(encoding="utf-8"))
    return summarize_samples(
        pairs_to_samples(payload), baseline_variant="off", measured_variant="on",
        target_resolution_relative=target_resolution_relative,
        resolution_multiplier=resolution_multiplier,
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Summarize compact paired MP CPU evidence")
    parser.add_argument("pairs", type=Path)
    parser.add_argument("--target-resolution", type=float, required=True)
    parser.add_argument("--multiplier", type=float, default=2.0)
    args = parser.parse_args(argv)
    result = summarize_paired_file(
        args.pairs, target_resolution_relative=args.target_resolution,
        resolution_multiplier=args.multiplier,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
