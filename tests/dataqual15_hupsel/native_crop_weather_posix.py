"""Remeasure original cold POSIX weather adapter artifact without rotation promotion."""
import json,zipfile
import native_crop_weather_evidence as evidence
BASE=evidence.BASE

def main():
    record=json.loads((BASE/'NATIVE_CROP_WEATHER_POSIX_20261105.json').read_text())
    path=BASE/'NATIVE_CROP_WEATHER_POSIX_20261105.zip';assert evidence.sha(path.read_bytes())==record['artifact_zip_sha256']
    with zipfile.ZipFile(path)as z:
        assert len(z.namelist())==len(set(z.namelist()))
        report={}
        for opt in ('O0','O2'):
            get=lambda name:z.read('weather-adapter-'+opt+'/'+name)
            report[opt]=dict(audit=evidence.audit(get,False),data_refusals=evidence.controls(get,False))
    assert report==record['report']
    print('ORIGINAL_COLD_POSIX_ACTUAL_WEATHER_NATIVE_SCHEMA_AND_REFUSALS_PASS')

if __name__=='__main__':main()
