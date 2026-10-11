from __future__ import annotations

import unittest

from tools.performance.mp_cpu_pairs import pairs_to_samples


class PairEvidenceTests(unittest.TestCase):
    def test_pair_expands_to_two_samples(self) -> None:
        payload = {
            "schema_version": "mp-cpu-baseline-pairs-v1",
            "target_affinity_cpus": [0],
            "physical_output_hashes": {"result.bal": "a" * 64},
            "pairs": [
                {
                    "cycle": 0,
                    "off_child_cpu_seconds": 1.0,
                    "on_child_cpu_seconds": 1.01,
                    "off_wall_elapsed_seconds": 2.0,
                    "on_wall_elapsed_seconds": 2.02,
                }
            ],
        }
        rows = pairs_to_samples(payload)
        self.assertEqual([row["variant"] for row in rows], ["off", "on"])
        self.assertEqual(rows[0]["target_affinity_cpus"], [0])


if __name__ == "__main__":
    unittest.main()
