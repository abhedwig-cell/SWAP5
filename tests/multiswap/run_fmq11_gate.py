#!/usr/bin/env python3
import sys
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent


def main() -> int:
    suite = unittest.defaultTestLoader.discover(
        str(HERE), pattern="test_fmq11_canonical_baseline_binding.py"
    )
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
