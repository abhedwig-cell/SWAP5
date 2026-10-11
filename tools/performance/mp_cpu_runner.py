from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import resource
import subprocess
import time
from pathlib import Path
from typing import Any, Mapping, Sequence

from tools.performance.mp_cpu_baseline import SAMPLE_SCHEMA_VERSION, validate_plan


def sha256_file(path: str | Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def normalized_sha256(path: str | Path) -> str:
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    text = re.sub(r"^\* Generated at:.*$", "* Generated at: <normalized>", text, flags=re.MULTILINE)
    text = re.sub(r"^\* compiler version :.*$", "* compiler version : <normalized>", text, flags=re.MULTILINE)
    text = re.sub(r"^\* compiler options :.*$", "* compiler options : <normalized>", text, flags=re.MULTILINE)
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _rusage_cpu_seconds(usage: resource.struct_rusage) -> float:
    return float(usage.ru_utime + usage.ru_stime)


def run_sample(
    *,
    executable: str | Path,
    cwd: str | Path,
    variant: str,
    cycle: int,
    environment: Mapping[str, str],
    target_cpus: Sequence[int],
    expected_exit_code: int,
    physical_outputs: Sequence[str],
    metrics_file: str | None = None,
) -> dict[str, Any]:
    if not hasattr(os, "sched_setaffinity"):
        raise RuntimeError("CPU affinity is not available on this platform")
    if not target_cpus:
        raise ValueError("target_cpus must not be empty")
    cwd = Path(cwd)
    executable = Path(executable).resolve()
    metrics_path = cwd / metrics_file if metrics_file else None
    if metrics_path is not None and metrics_path.exists():
        metrics_path.unlink()

    env = os.environ.copy()
    env.update({str(key): str(value) for key, value in environment.items()})
    load_before = list(os.getloadavg()) if hasattr(os, "getloadavg") else None
    usage_before = resource.getrusage(resource.RUSAGE_CHILDREN)
    started_ns = time.perf_counter_ns()

    def _pin_child() -> None:
        os.sched_setaffinity(0, set(target_cpus))

    completed = subprocess.run(
        [str(executable)],
        cwd=cwd,
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        preexec_fn=_pin_child,
        check=False,
    )
    ended_ns = time.perf_counter_ns()
    usage_after = resource.getrusage(resource.RUSAGE_CHILDREN)
    load_after = list(os.getloadavg()) if hasattr(os, "getloadavg") else None

    if completed.returncode != expected_exit_code:
        raise RuntimeError(
            f"unexpected process exit code {completed.returncode}; expected {expected_exit_code}"
        )

    hashes = {name: normalized_sha256(cwd / name) for name in physical_outputs}
    row: dict[str, Any] = {
        "schema_version": SAMPLE_SCHEMA_VERSION,
        "cycle": cycle,
        "variant": variant,
        "wall_elapsed_seconds": (ended_ns - started_ns) / 1_000_000_000.0,
        "child_cpu_seconds": _rusage_cpu_seconds(usage_after) - _rusage_cpu_seconds(usage_before),
        "child_user_seconds": usage_after.ru_utime - usage_before.ru_utime,
        "child_system_seconds": usage_after.ru_stime - usage_before.ru_stime,
        "minor_faults": usage_after.ru_minflt - usage_before.ru_minflt,
        "major_faults": usage_after.ru_majflt - usage_before.ru_majflt,
        "voluntary_context_switches": usage_after.ru_nvcsw - usage_before.ru_nvcsw,
        "involuntary_context_switches": usage_after.ru_nivcsw - usage_before.ru_nivcsw,
        "target_affinity_cpus": list(target_cpus),
        "loadavg_before": load_before,
        "loadavg_after": load_after,
        "hashes": hashes,
    }
    if metrics_path is not None and metrics_path.exists():
        metrics = json.loads(metrics_path.read_text(encoding="utf-8"))
        if "dynamic_swap_seconds" in metrics:
            row["internal_dynamic_seconds"] = float(metrics["dynamic_swap_seconds"])
    return row


def run_plan(
    plan: Mapping[str, Any], *, executable: str | Path, cwd: str | Path, output: str | Path
) -> None:
    errors = validate_plan(plan)
    if errors:
        raise ValueError("; ".join(errors))
    executable = Path(executable)
    expected_sha = plan.get("executable_sha256")
    if expected_sha is not None and sha256_file(executable) != expected_sha:
        raise ValueError("executable SHA-256 does not match plan")
    variants = plan["variants"]
    names = list(variants)
    if len(names) != 2:
        raise ValueError("controlled paired runner currently requires exactly two variants")
    target_cpus = plan["affinity"]["target_cpus"]
    outputs = plan["physical_outputs"]
    expected_exit = int(plan["expected_exit_code"])
    warmups = int(plan["warmup_runs_per_variant"])
    pairs = int(plan["predeclared_pairs"])

    for _ in range(warmups):
        for name in names:
            variant = variants[name]
            run_sample(
                executable=executable, cwd=cwd, variant=name, cycle=0,
                environment=variant.get("environment", variant), target_cpus=target_cpus,
                expected_exit_code=expected_exit, physical_outputs=outputs,
                metrics_file=variant.get("metrics_file") if isinstance(variant, Mapping) else None,
            )

    output = Path(output)
    with output.open("w", encoding="utf-8") as handle:
        for cycle in range(pairs):
            order = names if cycle % 2 == 0 else list(reversed(names))
            for name in order:
                variant = variants[name]
                row = run_sample(
                    executable=executable, cwd=cwd, variant=name, cycle=cycle,
                    environment=variant.get("environment", variant), target_cpus=target_cpus,
                    expected_exit_code=expected_exit, physical_outputs=outputs,
                    metrics_file=variant.get("metrics_file") if isinstance(variant, Mapping) else None,
                )
                handle.write(json.dumps(row, separators=(",", ":"), sort_keys=True) + "\n")
                handle.flush()


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run a controlled paired SWAP5 MP CPU benchmark")
    parser.add_argument("plan", type=Path)
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--cwd", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    plan = json.loads(args.plan.read_text(encoding="utf-8"))
    run_plan(plan, executable=args.executable, cwd=args.cwd, output=args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
