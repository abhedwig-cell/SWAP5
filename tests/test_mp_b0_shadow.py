from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.performance.mp_b0_shadow import (
    compare_physical_outputs,
    instrument_swap_main,
    normalize_physical_output,
    parse_rounded_water_balance,
    strip_intel_conditionals,
)


class ShadowToolTests(unittest.TestCase):
    def test_strip_intel_conditionals_selects_linux_standalone(self) -> None:
        source = """a\n!DEC$ IF DEFINED (multiswap)\nmulti\n!DEC$ ELSE\nstandalone\n!DEC$ END IF\n!DEC$ IF (linux==0)\nwindows\n!DEC$ END IF\nz\n"""
        result = strip_intel_conditionals(source, defined=frozenset(), linux=True)
        self.assertEqual(result, "a\nstandalone\nz\n")

    def test_unknown_dec_condition_fails(self) -> None:
        with self.assertRaises(ValueError):
            strip_intel_conditionals("!DEC$ IF SOMETHING\nx\n!DEC$ END IF\n")

    def test_instrument_swap_main_inserts_observer_at_call_boundary(self) -> None:
        source = (
            "use MOD_swap_base, only: unit_log, unit_wrn, sw_animo\n"
            "   iTask = 2\n"
            "   if (iCaller == 0) call swap(iCaller, iTask, tstart_in, tend_in)\n"
            "write(*,'(a)')' Swap normal completion!'\n"
        )
        result = instrument_swap_main(source)
        self.assertIn("use mp_shadow_observer", result)
        self.assertIn("call mp_dynamic_begin()", result)
        self.assertIn("call mp_dynamic_end()", result)
        self.assertIn("call mp_flush()", result)

    def test_output_normalization_only_removes_run_metadata(self) -> None:
        text = (
            "* Generated at: 2026-09-06 10:00\n"
            "* compiler version : A\n"
            "* compiler options : B\n"
            "Water=1.25\n"
        )
        normalized = normalize_physical_output(text)
        self.assertIn("Water=1.25", normalized)
        self.assertNotIn("2026-09-06", normalized)
        self.assertNotIn("version : A", normalized)

    def test_compare_physical_outputs_ignores_generated_timestamp(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            a = root / "a"
            b = root / "b"
            a.mkdir()
            b.mkdir()
            for name in ("result.bal", "result.blc"):
                (a / name).write_text("* Generated at: one\nValue 3.5\n")
                (b / name).write_text("* Generated at: two\nValue 3.5\n")
            self.assertEqual(
                compare_physical_outputs(a, b),
                {"result.bal": True, "result.blc": True},
            )

    def test_parse_rounded_water_balance(self) -> None:
        text = """Period             :  2004-01-01  until  2004-12-31
Final   :        76.02 cm
Initial :        76.38 cm
Change           -0.36 cm

Water balance components (cm)
In                           Out
=========================    ============================
Sum            :    80.55    Sum               :    80.91

Solute balance components (mg/cm2)
"""
        periods = parse_rounded_water_balance(text)
        self.assertEqual(len(periods), 1)
        self.assertAlmostEqual(periods[0].residual_cm, 0.0, places=12)


if __name__ == "__main__":
    unittest.main()
