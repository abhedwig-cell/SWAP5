import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parent
loader = unittest.TestLoader()
suite = loader.discover(str(ROOT), pattern="test_fmq16_fsi03_failclosed_admission.py")
result = unittest.TextTestRunner(verbosity=2).run(suite)
sys.exit(0 if result.wasSuccessful() else 1)
