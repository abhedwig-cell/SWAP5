"""Cross-source actual crop parameter gate, requires sibling PCSE checkout.

This test does NOT assert two independent crop cases should numerically match.
It confirms that the SWAP5 native rooted weather benchmark and the pinned
PCSE Spring_barley_301 are DIFFERENT crop parameter cases, and therefore
must not be admitted as a positive coupled scientific comparison.
"""
from pathlib import Path
import re
import hashlib
import json
import os
import sys
import unittest
import yaml

swap=Path(sys.argv[1]) if len(sys.argv)>1 else Path("swap")
pcse=Path(sys.argv[2]) if len(sys.argv)>2 else Path("pcse")
SOURCE=swap/"tests/fmig431/test_crop_file_weather_production.f90"
YAML=pcse/"pcse/tests/test_data/ext01_barley_wofost81_source.yaml"
SWAP_WEATHER=swap/"tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-andelst_meteo.999.gz"
PCSE_WEATHER=pcse/"pcse/tests/test_data/wofost81_qualification_weather.yaml"

def compare():
    source=SOURCE.read_text()
    start=source.index("  subroutine make_bundle(bundle)")
    stop=source.index("  end subroutine make_bundle",start)
    body=source[start:stop]
    def scalar(name):
        m=re.search(r"scalar%"+re.escape(name)+r"\s*=\s*([0-9.]+)",body,re.I)
        if m is None: raise ValueError("SWAP5 missing crop trait "+name)
        return float(m.group(1))
    data=yaml.safe_load(YAML.read_text())
    crop={key:value[0] for key,value in
          data["CropParameters"]["Varieties"]["Spring_barley_301"].items()
          if key!="Metadata"}
    return {
        "source_synthetic_TSUM1":scalar("vegetative_temperature_sum_required"),
        "pcse_barley_TSUM1":float(crop["TSUM1"]),
        "source_synthetic_TSUM2":scalar("generative_temperature_sum_required"),
        "pcse_barley_TSUM2":float(crop["TSUM2"]),
        "source_daylength_mode":int(scalar("development_daylength_mode")),
        "pcse_barley_daylength_mode":int(crop["IDSL"]),
    }

class TestParameterAuthority(unittest.TestCase):
    def test_real_parameter_sources_are_not_a_matched_pair(self):
        result=compare()
        self.assertEqual(result["source_synthetic_TSUM1"],1000)
        self.assertEqual(result["pcse_barley_TSUM1"],800)
        self.assertEqual(result["source_synthetic_TSUM2"],800)
        self.assertEqual(result["pcse_barley_TSUM2"],750)
        self.assertEqual(result["source_daylength_mode"],1)
        self.assertEqual(result["pcse_barley_daylength_mode"],0)
        self.assertNotEqual(result["source_synthetic_TSUM1"],result["pcse_barley_TSUM1"])
        self.assertNotEqual(result["source_daylength_mode"],result["pcse_barley_daylength_mode"])
        manifest={
            "schema":"F-WOF-EXT01/CROP-PARAMETER-PAIR/1",
            "swap5_source":"tests/fmig431/test_crop_file_weather_production.f90",
            "swap5_source_sha256":hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            "pcse_source":"pcse/tests/test_data/ext01_barley_wofost81_source.yaml",
            "pcse_source_sha256":hashlib.sha256(YAML.read_bytes()).hexdigest(),
            "values":result,
            "swap5_weather_source_sha256":hashlib.sha256(SWAP_WEATHER.read_bytes()).hexdigest(),
            "pcse_weather_source_sha256":hashlib.sha256(PCSE_WEATHER.read_bytes()).hexdigest(),
            "swap5_source_crop_calendar":"1999-01-20 physical rooted weather fixture",
            "pcse_crop_calendar":"2010-04-16 Spring_barley_301",
            "same_calendar_and_weather_case":False,
            "same_crop_parameter_case":False,
            "positive_daily_science_admitted":False
        }
        output=os.environ.get("EXT01_MANIFEST_PATH")
        if output:
            Path(output).write_text(json.dumps(manifest,sort_keys=True,indent=2)+"\\n")
        print("EXT01_AUTHENTIC_SWAP_VS_PCSE_CROP_PARAMETER_NONMATCH_PROVEN")
if __name__=="__main__":
    sys.argv=[sys.argv[0]]
    unittest.main()
