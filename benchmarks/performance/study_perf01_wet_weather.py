"""Prepare rain-only scenarios for the existing exact live-weather executable."""
import argparse
from decimal import Decimal
import gzip
import hashlib
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()


def prepare(build,out,multiplier):
    build=build.resolve();out=out.resolve();out.mkdir(parents=True,exist_ok=False)
    record=json.loads((build/'BUILD.json').read_text())
    assert record['status']=='BUILT' and sha((build/'weather').read_bytes())==record['executable_sha256']
    for p,h in record['sources'].items():
        source=build/'grid_stubs.f90' if p=='tests/fsi/fsi04_real_headcalc_stubs.f90' else ROOT/p
        if p=='src/runtime/mod_fmr_serialized_multiswap_runtime.f90':
            assert sha(source.read_bytes())==record['observer_original_sha256']
            source=build/'observed_serial_runtime.f90'
        if p=='src/runtime/mod_fmr_production_application_bootstrap.f90':
            assert sha(source.read_bytes())==record['surface_observer_original_sha256']
            source=build/'observed_bootstrap.f90'
        assert sha(source.read_bytes())==h,p
    original=(build/'weather.999').read_bytes()
    authority=gzip.decompress((ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-andelst_meteo.999.gz').read_bytes())
    assert original==authority,'Weather baseline differs from the recorded original source'
    lines=original.decode().splitlines(keepends=True)
    count=0;total=Decimal(0)
    for i,line in enumerate(lines):
        matches=list(re.finditer(r'\S+',line));values=[x[0] for x in matches]
        if len(values)!=12 or values[0]!="'ANDE-M'":continue
        assert values[3]=='1999'
        rain=Decimal(values[9])*multiplier
        a,b=matches[9].span();lines[i]=line[:a]+str(rain)+line[b:]
        after=lines[i].split()
        assert after[:9]==values[:9] and after[10:]==values[10:]
        count+=1;total+=rain
    assert count==116
    modified=''.join(lines).encode()
    (out/'weather.999').write_bytes(modified)
    (out/'weather').symlink_to(build/'weather')
    record.update(parent_build=str(build),forcing_variant={'rain_multiplier':str(multiplier),
        'source_weather_sha256':sha(original),'scenario_weather_sha256':sha(modified),
        'modified_records':count,'all116day_rain_mm':str(total),'other_record_tokens_exact':True},
        weather_sha256=sha(modified),build_method='Reuse exact qualified native executable; rain-only input variant, no compilation')
    (out/'BUILD.json').write_text(json.dumps(record,indent=2)+'\n')
    return record['forcing_variant']


if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--build',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--rain-multiplier',type=Decimal,required=True)
    a=ap.parse_args();assert a.rain_multiplier>1
    print(json.dumps(prepare(a.build,a.output,a.rain_multiplier)))
