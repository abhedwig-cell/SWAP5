"""Preserve the sixteen actual unselected short source/native postimages once."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile
from groundwater_snow_archive_storage import store_original

ROOT=Path(__file__).resolve().parents[2]
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work',type=Path,required=True)
    a=p.parse_args();ev=a.work/'evidence';proof=ROOT/'integration/f-ci/nomacro-complete01'
    for opt in ('O0','O2'):
        profile=ev/('implicit-frost-unselected-postimages-'+opt+'-v1')
        q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_EIGHT_UNSELECTED_IMPLICIT_FROST_DEPENDENCY_POSTIMAGES_PASS'
        files={};projection={}
        for path in sorted(profile.rglob('*')):
            if path.is_file():files['profiles/'+path.relative_to(ev).as_posix()]=path
        baseline=ev/('FROST_IMPLICIT_UNSELECTED_BASELINES_'+opt+'_V1.json')
        assert SHA(baseline.read_bytes())==q['baseline_sha256'];files['unselected-observations/'+baseline.name]=baseline
        for item in q['profiles'].values():
            build=Path(item['build_root']);assert build.is_relative_to(a.work)
            prefix='builds/'+build.relative_to(a.work).as_posix()
            projection[str(build)]=dict(prefix=prefix,actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()))
            for path in sorted(build.iterdir()):
                if path.is_file() and (path.name=='BUILD.json' or path.suffix.lower() in ('.f90','.exe','.dll','.so')):files[prefix+'/'+path.name]=path
        name='FROST_IMPLICIT_WINDOWS_UNSELECTED_'+opt+'_RAW_ARCHIVE.zip';archive=ev/name;record=proof/Path(name).with_suffix('.json')
        assert not archive.exists() and not record.exists();members={}
        with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
            for member,path in sorted(files.items()):
                raw=path.read_bytes();z.writestr(member,raw);members[member]=dict(bytes=len(raw),sha256=SHA(raw))
            member='UNSELECTED_COMPILED_PROJECTION_V1.json';raw=(json.dumps(projection,indent=2)+'\n').encode()
            z.writestr(member,raw);members[member]=dict(bytes=len(raw),sha256=SHA(raw))
        stored=store_original(archive,proof,name)
        record.write_text(json.dumps(dict(status='NEUTRAL_ACTUAL_UNSELECTED_IMPLICIT_FROST_POSTIMAGES_RAW_PENDING_ADMISSION',**stored,members=members,canonical_admission=False),indent=2)+'\n')
        print(opt,stored['bytes'],stored['sha256'],len(members),flush=True)


if __name__=='__main__':main()
