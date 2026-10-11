from __future__ import annotations

import unittest

from tools.performance.mp_cpu_runner import run_sample


class CpuRunnerTests(unittest.TestCase):
    def test_empty_affinity_rejected(self) -> None:
        with self.assertRaises(ValueError):
            run_sample(
                executable="/bin/true",
                cwd=".",
                variant="off",
                cycle=0,
                environment={},
                target_cpus=[],
                expected_exit_code=0,
                physical_outputs=[],
            )


if __name__ == "__main__":
    unittest.main()
