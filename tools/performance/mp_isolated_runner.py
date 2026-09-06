from __future__ import annotations

import argparse
import json
import os
import platform
import re
import shutil
from pathlib import Path
from typing import Any, Mapping, Sequence

CONTRACT_SCHEMA_VERSION = "mp-isolated-runner-contract-v1"
SNAPSHOT_SCHEMA_VERSION = "mp-isolated-runner-snapshot-v1"
READINESS_SCHEMA_VERSION = "mp-isolated-runner-readiness-v1"


def _read_text(path: str | Path) -> str | None:
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return None


def parse_cpu_list(text: str) -> list[int]:
    cpus: set[int] = set()
    for token in text.split(","):
        token = token.strip()
        if not token:
            continue
        if "-" in token:
            start_text, end_text = token.split("-", 1)
            start, end = int(start_text), int(end_text)
            if start < 0 or end < start:
                raise ValueError(f"invalid CPU range: {token}")
            cpus.update(range(start, end + 1))
        else:
            cpu = int(token)
            if cpu < 0:
                raise ValueError(f"invalid CPU id: {cpu}")
            cpus.add(cpu)
    if not cpus:
        raise ValueError("CPU list is empty")
    return sorted(cpus)


def _cpu_model_and_hypervisor() -> tuple[str | None, bool | None]:
    text = _read_text("/proc/cpuinfo")
    if text is None:
        return None, None
    model = None
    hypervisor = False
    for line in text.splitlines():
        lower = line.lower()
        if model is None and lower.startswith("model name") and ":" in line:
            model = line.split(":", 1)[1].strip()
        if lower.startswith("flags") and ":" in line:
            flags = set(line.split(":", 1)[1].split())
            if "hypervisor" in flags:
                hypervisor = True
    return model, hypervisor


def _cpu_stat() -> dict[str, int] | None:
    text = _read_text("/sys/fs/cgroup/cpu.stat")
    if text is None:
        return None
    result: dict[str, int] = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1].isdigit():
            result[parts[0]] = int(parts[1])
    return result


def _frequency_metadata(cpu: int) -> dict[str, str | None]:
    base = Path(f"/sys/devices/system/cpu/cpu{cpu}/cpufreq")
    return {
        "scaling_driver": _read_text(base / "scaling_driver"),
        "scaling_governor": _read_text(base / "scaling_governor"),
        "scaling_min_freq": _read_text(base / "scaling_min_freq"),
        "scaling_max_freq": _read_text(base / "scaling_max_freq"),
    }


def _thread_siblings(cpu: int) -> list[int] | None:
    text = _read_text(f"/sys/devices/system/cpu/cpu{cpu}/topology/thread_siblings_list")
    if not text:
        return None
    try:
        return parse_cpu_list(text)
    except ValueError:
        return None


def host_snapshot(target_cpus: Sequence[int]) -> dict[str, Any]:
    target = sorted(set(int(cpu) for cpu in target_cpus))
    if not target or any(cpu < 0 for cpu in target):
        raise ValueError("target_cpus must contain non-negative CPU ids")
    affinity = sorted(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else None
    cpuset_text = _read_text("/sys/fs/cgroup/cpuset.cpus.effective")
    cpuset = parse_cpu_list(cpuset_text) if cpuset_text else None
    model, hypervisor = _cpu_model_and_hypervisor()
    isolation_tokens: list[str] = []
    cmdline = _read_text("/proc/cmdline") or ""
    for key in ("isolcpus", "nohz_full", "rcu_nocbs"):
        match = re.search(rf"(?:^|\s){key}=([^\s]+)", cmdline)
        if match:
            isolation_tokens.append(f"{key}={match.group(1)}")
    return {
        "schema_version": SNAPSHOT_SCHEMA_VERSION,
        "runner": {
            "name": os.environ.get("RUNNER_NAME"),
            "os": os.environ.get("RUNNER_OS") or platform.system(),
            "arch": os.environ.get("RUNNER_ARCH") or platform.machine(),
        },
        "platform": platform.platform(),
        "kernel_release": platform.release(),
        "cpu_model": model,
        "hypervisor_flag": hypervisor,
        "logical_cpu_count": os.cpu_count(),
        "process_affinity_cpus": affinity,
        "cpuset_effective_cpus": cpuset,
        "cpu_max": _read_text("/sys/fs/cgroup/cpu.max"),
        "cpu_stat": _cpu_stat(),
        "kernel_isolation_tokens": isolation_tokens,
        "target_cpus": target,
        "frequency": {str(cpu): _frequency_metadata(cpu) for cpu in target},
        "thread_siblings": {str(cpu): _thread_siblings(cpu) for cpu in target},
        "tools": {
            "python3": shutil.which("python3"),
            "gfortran": shutil.which("gfortran"),
        },
    }


def validate_contract(contract: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    if contract.get("schema_version") != CONTRACT_SCHEMA_VERSION:
        errors.append(f"schema_version must be {CONTRACT_SCHEMA_VERSION}")
    labels = contract.get("required_runner_labels")
    if not isinstance(labels, list) or not labels or any(not isinstance(v, str) or not v for v in labels):
        errors.append("required_runner_labels must be a non-empty string list")
    elif "self-hosted" not in labels:
        errors.append("required_runner_labels must include self-hosted")
    target = contract.get("target_resolution_relative")
    if not isinstance(target, (int, float)) or not 0 < float(target) < 1:
        errors.append("target_resolution_relative must be between 0 and 1")
    req = contract.get("requirements")
    required_bools = (
        "require_linux",
        "require_target_cpus_in_affinity",
        "require_target_cpus_in_cpuset",
        "require_unbounded_cgroup_cpu_quota",
        "require_frequency_metadata",
        "require_reserved_smt_siblings",
        "require_b0_distribution_identity",
        "require_final_mp7_host_admission",
    )
    if not isinstance(req, Mapping):
        errors.append("requirements must be an object")
    else:
        for name in required_bools:
            if req.get(name) is not True:
                errors.append(f"requirements.{name} must be true")
    b0_hash = contract.get("b0_distribution_sha256")
    if not isinstance(b0_hash, str) or len(b0_hash) != 64:
        errors.append("b0_distribution_sha256 must be a SHA-256 string")
    att = contract.get("required_attestation_fields")
    if not isinstance(att, list) or not att or any(not isinstance(v, str) or not v for v in att):
        errors.append("required_attestation_fields must be a non-empty string list")
    return errors


def validate_readiness(readiness: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    if readiness.get("schema_version") != READINESS_SCHEMA_VERSION:
        errors.append(f"schema_version must be {READINESS_SCHEMA_VERSION}")
    status = readiness.get("status")
    if status not in {"INFRASTRUCTURE_PENDING", "RUNNER_CONTRACT_READY", "HOST_ADMITTED"}:
        errors.append("status is invalid")
    if status != "HOST_ADMITTED" and readiness.get("cpu_baseline_established") is not False:
        errors.append("cpu_baseline_established must be false until HOST_ADMITTED")
    if status == "INFRASTRUCTURE_PENDING" and readiness.get("admission_evidence") is not None:
        errors.append("pending infrastructure must not point at admission evidence")
    return errors


def assess_runner(
    contract: Mapping[str, Any],
    snapshot: Mapping[str, Any],
    attestation: Mapping[str, Any],
    reference_identity: Mapping[str, Any],
) -> dict[str, Any]:
    contract_errors = validate_contract(contract)
    if contract_errors:
        raise ValueError("; ".join(contract_errors))
    if snapshot.get("schema_version") != SNAPSHOT_SCHEMA_VERSION:
        raise ValueError(f"snapshot schema_version must be {SNAPSHOT_SCHEMA_VERSION}")
    target = snapshot.get("target_cpus")
    if not isinstance(target, list) or not target or any(not isinstance(v, int) or v < 0 for v in target):
        raise ValueError("snapshot.target_cpus must be a non-empty integer list")
    target_set = set(target)
    affinity = snapshot.get("process_affinity_cpus")
    cpuset = snapshot.get("cpuset_effective_cpus")

    freq = snapshot.get("frequency")
    freq_ok = isinstance(freq, Mapping)
    if freq_ok:
        for cpu in target:
            item = freq.get(str(cpu))
            if not isinstance(item, Mapping):
                freq_ok = False
                break
            if not any(item.get(k) for k in ("scaling_driver", "scaling_governor", "scaling_min_freq", "scaling_max_freq")):
                freq_ok = False
                break

    reserved = attestation.get("reserved_cpus")
    reserved_set = set(reserved) if isinstance(reserved, list) and all(isinstance(v, int) for v in reserved) else set()
    siblings = snapshot.get("thread_siblings")
    siblings_ok = isinstance(siblings, Mapping) and bool(reserved_set)
    if siblings_ok:
        for cpu in target:
            sibling_list = siblings.get(str(cpu))
            if not isinstance(sibling_list, list) or not set(sibling_list).issubset(reserved_set):
                siblings_ok = False
                break

    cpu_max = snapshot.get("cpu_max")
    unbounded = isinstance(cpu_max, str) and cpu_max.split()[0] == "max"
    runner = snapshot.get("runner", {})
    att_fields = contract["required_attestation_fields"]
    attestation_complete = all(attestation.get(name) not in (None, "", False) for name in att_fields)
    reference_ok = (
        reference_identity.get("passed") is True
        and reference_identity.get("distribution_sha256") == contract.get("b0_distribution_sha256")
    )

    gates = {
        "linux_runner": str(runner.get("os", "")).lower() == "linux",
        "target_cpus_in_affinity": isinstance(affinity, list) and target_set.issubset(set(affinity)),
        "target_cpus_in_cpuset": isinstance(cpuset, list) and target_set.issubset(set(cpuset)),
        "unbounded_cgroup_cpu_quota": unbounded,
        "frequency_metadata_present": freq_ok,
        "reserved_smt_siblings": siblings_ok,
        "required_tools_present": bool(snapshot.get("tools", {}).get("python3")) and bool(snapshot.get("tools", {}).get("gfortran")),
        "operator_attestation_complete": attestation_complete,
        "b0_distribution_identity": reference_ok,
        "runner_dedicated": attestation.get("runner_dedicated_to_benchmark") is True,
        "unrelated_workloads_excluded": attestation.get("unrelated_workloads_excluded") is True,
        "frequency_policy_controlled": attestation.get("frequency_policy_controlled") is True,
    }
    contract_ready = all(gates.values())
    return {
        "schema_version": "mp-isolated-runner-assessment-v1",
        "target_cpus": target,
        "gates": gates,
        "runner_contract_ready": contract_ready,
        "host_admitted_for_cpu_baseline": False,
        "cpu_baseline_established": False,
        "next_gate": "run MP-7 host-admission protocol on this runner" if contract_ready else "fix runner contract failures before performance qualification",
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="SWAP5 isolated performance-runner contract")
    sub = parser.add_subparsers(dest="command", required=True)
    val = sub.add_parser("validate-contract")
    val.add_argument("contract", type=Path)
    ready = sub.add_parser("validate-readiness")
    ready.add_argument("readiness", type=Path)
    probe = sub.add_parser("probe")
    probe.add_argument("--target-cpus", required=True)
    assess = sub.add_parser("assess")
    assess.add_argument("contract", type=Path)
    assess.add_argument("snapshot", type=Path)
    assess.add_argument("attestation", type=Path)
    assess.add_argument("reference_identity", type=Path)
    args = parser.parse_args(argv)

    if args.command == "validate-contract":
        errors = validate_contract(json.loads(args.contract.read_text(encoding="utf-8")))
        print(json.dumps({"valid": not errors, "errors": errors}, indent=2, sort_keys=True))
        return 0 if not errors else 1
    if args.command == "validate-readiness":
        errors = validate_readiness(json.loads(args.readiness.read_text(encoding="utf-8")))
        print(json.dumps({"valid": not errors, "errors": errors}, indent=2, sort_keys=True))
        return 0 if not errors else 1
    if args.command == "probe":
        print(json.dumps(host_snapshot(parse_cpu_list(args.target_cpus)), indent=2, sort_keys=True))
        return 0
    if args.command == "assess":
        result = assess_runner(
            json.loads(args.contract.read_text(encoding="utf-8")),
            json.loads(args.snapshot.read_text(encoding="utf-8")),
            json.loads(args.attestation.read_text(encoding="utf-8")),
            json.loads(args.reference_identity.read_text(encoding="utf-8")),
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result["runner_contract_ready"] else 2
    raise AssertionError("unreachable")


if __name__ == "__main__":
    raise SystemExit(main())
