from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from tools.vq.balance import parse_bal, parse_blc


BAL = """Period             :  2002-01-01  until  2002-12-31
Final   :        78.01 cm       0.0 mg/cm2
Initial :        75.19 cm       0.0 mg/cm2
Change            2.82 cm       0.0 mg/cm2
Water balance components (cm)
Rain + snow    :    84.18    Interception      :     4.25
Irrigation     :     2.40    Transpiration     :    34.73
                             Soil evaporation  :    11.99
                             Drainage level 1  :    32.76
Sum            :    86.58    Sum               :    83.76
Solute balance components (mg/cm2)
"""

BLC = """Period             :  2002-01-01  until  2002-12-31
Balance Deviation   0.00    0.00    0.00   -0.00
"""


class BalanceTests(unittest.TestCase):
    def test_bal_extracts_reference_values_and_residual(self):
        with TemporaryDirectory() as d:
            p = Path(d) / "result.bal"
            p.write_text(BAL)
            period = parse_bal(p)["periods"][0]
            self.assertEqual(period["components_cm"]["rain + snow"], 84.18)
            self.assertEqual(period["components_cm"]["drainage level 1"], 32.76)
            self.assertAlmostEqual(period["rounded_residual_cm"], 0.0, places=12)

    def test_blc_extracts_subsystem_deviation(self):
        with TemporaryDirectory() as d:
            p = Path(d) / "result.blc"
            p.write_text(BLC)
            dev = parse_blc(p)["periods"][0]["balance_deviation_cm"]
            self.assertEqual(dev, {"plant": 0.0, "snow": 0.0, "pond": 0.0, "soil": -0.0})


if __name__ == "__main__":
    unittest.main()
