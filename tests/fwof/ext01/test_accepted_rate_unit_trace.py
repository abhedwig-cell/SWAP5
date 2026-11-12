"""Executable unit/phase trace for F-WOF-EXT01; no physical unit guesswork."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[3]
BOOT=ROOT/"src/runtime/mod_fmr_production_application_bootstrap.f90"
LINEAGE=ROOT/"src/runtime/mod_fmr_wofost_accepted_window_lineage.f90"
ET=ROOT/"src/process/mod_reference_et_demand_process.f90"

def source_contract():
    boot=BOOT.read_text()
    lineage=LINEAGE.read_text()
    et=ET.read_text()
    checks={
      "potential_cm_per_day_declared": "potential_transpiration_cm_per_day" in et,
      "reference_et_mm_to_cm": "transpiration_reference_et_mm_per_day * 0.1_real64" in et,
      "potential_routed_to_root_input":
        "root_input%potential_transpiration=common%reference_et_demand%potential_transpiration_cm_per_day" in boot,
      "actual_from_root_sink_sum":
        "qrot=sum(effective(1)%root_extraction_sink);ptra=root_input%potential_transpiration" in boot,
      "interval_accepted_process_integrals":
        "call accumulate_wofost_trial_process_rate(trial,t0,t1,qrot,ptra,s" in boot,
      "actual_integration": "actual_add = actual_root_uptake_rate * dt" in lineage,
      "potential_integration": "potential_add = potential_transpiration_rate * dt" in lineage,
      "no_double_timestep":
        "trial%actual_root_uptake_integral = actual_new" in lineage,
    }
    if not all(checks.values()):
        raise ValueError("SWAP5 rooted hydrology unit or interval transport changed: "+
                         str({k:v for k,v in checks.items() if not v}))
    return checks

class TestUnitPhaseTrace(unittest.TestCase):
    def test_current_accepted_hydrology_rate_integral_path(self):
        checks=source_contract()
        self.assertEqual(len(checks),8)
        print("EXT01_SWAP5_ACCEPTED_RATE_INTEGRAL_SOURCE_TRACE_PASS")
    def test_source_is_not_a_full_cross_model_unit_attestation(self):
        self.assertTrue(source_contract()["potential_cm_per_day_declared"])
        # This static source-path trace alone cannot prove the numerical
        # PCSE physical day/calendar, soil mass audit, or sink sign convention.
        self.assertTrue((ROOT/"tests/fwof/ext01/export_authentic_accepted_witness.py").exists())
        print("EXT01_SOURCE_TRACE_NOT_POSITIVE_PCSE_COUPLING")
if __name__=="__main__":
    unittest.main()
