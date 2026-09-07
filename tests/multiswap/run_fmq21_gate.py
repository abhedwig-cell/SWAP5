#!/usr/bin/env python3
import unittest

suite = unittest.defaultTestLoader.loadTestsFromName('tests.multiswap.test_fmq21_fsi06_fvq12_ownership_admission')
result = unittest.TextTestRunner(verbosity=2).run(suite)
raise SystemExit(0 if result.wasSuccessful() else 1)
