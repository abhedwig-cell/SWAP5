import unittest


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromName(
        "test_fmq19_fsi05_production_workspace_admission",
        module=None,
    )
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)
