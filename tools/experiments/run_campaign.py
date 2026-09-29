#!/usr/bin/env python3
"""Run a local Cartesian experiment campaign without using GitHub Actions."""

from __future__ import annotations

import argparse
import csv
import itertools
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
from typing import Any


def _git_head(repo: Path) -> str | None:
    try:
        return subprocess.check_output(
            ["git", "-C", str(repo), "rev-parse", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def _cases(matrix: dict[str, list[Any]]) -> list[dict[str, Any]]:
    if not matrix:
        return [{}]
    keys = list(matrix)
    return [dict(zip(keys, values)) for values in itertools.product(*(matrix[k] for k in keys))]


def _slug(index: int, params: dict[str, Any]) -> str:
    parts = [f"{k}-{v}" for k, v in params.items()]
    raw = "__".join(parts) if parts else "default"
    safe = "".join(ch if ch.isalnum() or ch in "._-" else "_" for ch in raw)
    return f"{index:05d}_{safe[:180]}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("config", type=Path)
    ap.add_argument("--output", type=Path, default=Path(".scratch/campaigns"))
    ap.add_argument("--repo", type=Path, default=Path("."))
    ap.add_argument("--keep-going", action="store_true")
    args = ap.parse_args()

    cfg = json.loads(args.config.read_text(encoding="utf-8"))
    name = cfg.get("name") or args.config.stem
    command = cfg["command"]
    if not isinstance(command, list) or not command:
        raise SystemExit("'command' must be a non-empty JSON array")

    template = Path(cfg.get("workdir_template", ".")).resolve()
    root = (args.output / name).resolve()
    root.mkdir(parents=True, exist_ok=True)

    cases = _cases(cfg.get("matrix", {}))
    meta = {
        "name": name,
        "config": str(args.config.resolve()),
        "git_head": _git_head(args.repo.resolve()),
        "command": command,
        "workdir_template": str(template),
        "case_count": len(cases),
        "created_unix": time.time(),
    }
    (root / "campaign.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")

    jsonl = root / "results.jsonl"
    rows: list[dict[str, Any]] = []

    with jsonl.open("w", encoding="utf-8") as jf:
        for i, params in enumerate(cases, start=1):
            case_dir = root / "cases" / _slug(i, params)
            if case_dir.exists():
                shutil.rmtree(case_dir)
            shutil.copytree(template, case_dir)

            env = os.environ.copy()
            for key, value in params.items():
                env[f"SWAP5_PARAM_{key.upper()}"] = str(value)

            t0 = time.perf_counter()
            proc = subprocess.run(
                command,
                cwd=case_dir,
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            elapsed = time.perf_counter() - t0
            (case_dir / "stdout.log").write_text(proc.stdout, encoding="utf-8", errors="replace")
            (case_dir / "stderr.log").write_text(proc.stderr, encoding="utf-8", errors="replace")

            row = {
                "case": i,
                "case_dir": str(case_dir),
                "returncode": proc.returncode,
                "wall_seconds": elapsed,
                **params,
            }
            rows.append(row)
            jf.write(json.dumps(row, sort_keys=True) + "\n")
            jf.flush()

            print(f"[{i}/{len(cases)}] rc={proc.returncode} {elapsed:.3f}s {params}", flush=True)
            if proc.returncode != 0 and not args.keep_going:
                break

    keys = ["case", "case_dir", "returncode", "wall_seconds"]
    extra = list(cfg.get("matrix", {}).keys())
    with (root / "results.csv").open("w", newline="", encoding="utf-8") as cf:
        writer = csv.DictWriter(cf, fieldnames=keys + extra)
        writer.writeheader()
        writer.writerows(rows)

    failures = sum(int(r["returncode"] != 0) for r in rows)
    print(f"campaign={name} completed={len(rows)}/{len(cases)} failures={failures} output={root}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
