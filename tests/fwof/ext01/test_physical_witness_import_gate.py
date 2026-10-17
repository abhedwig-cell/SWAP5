"""F-WOF-EXT01 physical-to-crop evidence admission gate.

The observed authentic SWAP Fortran receipt has native integrals but not a
validated PCSE calendar and cm/day conversion. Fail closed; no synthetic
substitution of those missing facts. A complete, independently attested
receipt is a distinct future contract.
"""
import json
import math
import unittest

REQUIRED={"schema","source","witness_column","source_fortran_day",
          "independent_matching_confirmations",
          "actual_root_uptake_native_integral",
          "potential_transpiration_native_integral",
          "matched_accepted_uptake_native_integral",
          "calendar_date","unit_conversion_to_cm","acceptance",
          "pcse_daily_import_permitted","reason"}

def accept_for_pcse(witness, expected_day):
    if set(witness)!=REQUIRED or witness.get("schema")!="F-WOF-EXT01/SWAP-WITNESS/1":
        raise ValueError("wrong SWAP witness schema")
    if witness.get("acceptance")!="observed-passing-native-test":
        raise ValueError("unaccepted SWAP hydrology")
    for k in ("actual_root_uptake_native_integral","potential_transpiration_native_integral",
              "matched_accepted_uptake_native_integral"):
        v=witness[k]
        if not isinstance(v,(int,float)) or isinstance(v,bool) or not math.isfinite(v):
            raise ValueError("invalid native flux")
    if witness["matched_accepted_uptake_native_integral"]!=witness["actual_root_uptake_native_integral"]:
        raise ValueError("root uptake not reconciled")
    if not witness["pcse_daily_import_permitted"]:
        raise ValueError("native SWAP witness not admitted for PCSE import")
    if witness["calendar_date"]!=expected_day:
        raise ValueError("SWAP-PCSE calendar mismatch")
    factor=witness["unit_conversion_to_cm"]
    if not isinstance(factor,(int,float)) or not math.isfinite(factor) or factor<=0:
        raise ValueError("missing documented unit mapping")
    raise ValueError("witness-v1 has no accepted revision, unit authority or same-day meteo; use future fully attested contract")

class TestPhysicalGate(unittest.TestCase):
    def setUp(self):
        self.witness=dict(schema="F-WOF-EXT01/SWAP-WITNESS/1",
            source="test_crop_file_weather_production.f90",
            witness_column=1,source_fortran_day=2,independent_matching_confirmations=3,
            actual_root_uptake_native_integral=1.0370706377336118e-3,
            potential_transpiration_native_integral=1.0370706377336118e-3,
            matched_accepted_uptake_native_integral=1.0370706377336118e-3,
            calendar_date=None,unit_conversion_to_cm=None,
            acceptance="observed-passing-native-test",
            pcse_daily_import_permitted=False,reason="not mapped")
    def test_authentic_witness_rejected(self):
        with self.assertRaisesRegex(ValueError,"not admitted"):
            accept_for_pcse(self.witness,"2010-05-17")
    def test_forged_date_and_units_still_not_admitted(self):
        w={**self.witness, "calendar_date":"2010-05-17",
           "unit_conversion_to_cm":1.0,"pcse_daily_import_permitted":True}
        with self.assertRaisesRegex(ValueError,"future fully attested"):
            accept_for_pcse(w,"2010-05-17")
    def test_mismatched_repeated_flux_rejected(self):
        w={**self.witness,"matched_accepted_uptake_native_integral":.01}
        with self.assertRaisesRegex(ValueError,"root uptake"):
            accept_for_pcse(w,"2010-05-17")
if __name__=="__main__":
    unittest.main()
