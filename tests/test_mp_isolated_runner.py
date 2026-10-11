from __future__ import annotations

import copy
import unittest

from tools.performance.mp_isolated_runner import (
    assess_runner,
    parse_cpu_list,
    validate_contract,
    validate_readiness,
)


def contract():
    return {
        "schema_version": "mp-isolated-runner-contract-v1",
        "required_runner_labels": ["self-hosted", "linux", "x64", "swap5-performance"],
        "target_resolution_relative": 0.01,
        "b0_distribution_sha256": "2" * 64,
        "requirements": {
            "require_linux": True,
            "require_target_cpus_in_affinity": True,
            "require_target_cpus_in_cpuset": True,
            "require_unbounded_cgroup_cpu_quota": True,
            "require_frequency_metadata": True,
            "require_reserved_smt_siblings": True,
            "require_b0_distribution_identity": True,
            "require_final_mp7_host_admission": True,
        },
        "required_attestation_fields": [
            "isolation_method",
            "reserved_cpus",
            "runner_dedicated_to_benchmark",
            "unrelated_workloads_excluded",
            "frequency_policy_controlled",
        ],
    }


def snapshot():
    return {
        "schema_version": "mp-isolated-runner-snapshot-v1",
        "runner": {"name": "perf-1", "os": "Linux", "arch": "X64"},
        "target_cpus": [2],
        "process_affinity_cpus": [2, 3],
        "cpuset_effective_cpus": [2, 3],
        "cpu_max": "max 100000",
        "frequency": {
            "2": {
                "scaling_driver": "intel_pstate",
                "scaling_governor": "performance",
                "scaling_min_freq": "2000000",
                "scaling_max_freq": "3000000",
            }
        },
        "thread_siblings": {"2": [2, 3]},
        "tools": {"python3": "/usr/bin/python3", "gfortran": "/usr/bin/gfortran"},
    }


def reference_identity():
    return {"passed": True, "distribution_sha256": "2" * 64}


def attestation():
    return {
        "isolation_method": "reserved-physical-core",
        "reserved_cpus": [2, 3],
        "runner_dedicated_to_benchmark": True,
        "unrelated_workloads_excluded": True,
        "frequency_policy_controlled": True,
    }


class IsolatedRunnerTests(unittest.TestCase):
    def test_parse_cpu_list(self) -> None:
        self.assertEqual(parse_cpu_list("0-2,4,6-7"), [0, 1, 2, 4, 6, 7])

    def test_contract_valid(self) -> None:
        self.assertEqual(validate_contract(contract()), [])

    def test_clean_runner_contract_can_be_ready_but_not_baseline_admitted(self) -> None:
        result = assess_runner(contract(), snapshot(), attestation(), reference_identity())
        self.assertTrue(result["runner_contract_ready"])
        self.assertFalse(result["host_admitted_for_cpu_baseline"])
        self.assertFalse(result["cpu_baseline_established"])

    def test_cpu_quota_fails_closed(self) -> None:
        item = snapshot()
        item["cpu_max"] = "100000 100000"
        result = assess_runner(contract(), item, attestation(), reference_identity())
        self.assertFalse(result["runner_contract_ready"])
        self.assertFalse(result["gates"]["unbounded_cgroup_cpu_quota"])

    def test_missing_smt_reservation_fails_closed(self) -> None:
        att = attestation()
        att["reserved_cpus"] = [2]
        result = assess_runner(contract(), snapshot(), att, reference_identity())
        self.assertFalse(result["gates"]["reserved_smt_siblings"])

    def test_wrong_b0_identity_fails_closed(self) -> None:
        identity = reference_identity()
        identity["distribution_sha256"] = "3" * 64
        result = assess_runner(contract(), snapshot(), attestation(), identity)
        self.assertFalse(result["gates"]["b0_distribution_identity"])

    def test_pending_readiness_cannot_claim_baseline(self) -> None:
        readiness = {
            "schema_version": "mp-isolated-runner-readiness-v1",
            "status": "INFRASTRUCTURE_PENDING",
            "admission_evidence": None,
            "cpu_baseline_established": False,
        }
        self.assertEqual(validate_readiness(readiness), [])
        bad = copy.deepcopy(readiness)
        bad["cpu_baseline_established"] = True
        self.assertTrue(validate_readiness(bad))


if __name__ == "__main__":
    unittest.main()
