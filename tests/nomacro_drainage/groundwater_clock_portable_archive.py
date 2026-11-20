"""Verify original unchanged GitHub groundwater clock science artifacts."""
import argparse
import hashlib
import json
import os
from pathlib import Path,PurePosixPath
import stat
import zipfile

from groundwater_clock_forensics import audit
from ordinary_pond_evidence import read,digest,require
from groundwater_clock_custody import audit as source_custody


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('archive','artifacts','extract','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--artifact-id',type=int,required=True);a=p.parse_args()
    record=next(v for v in read(a.artifacts)['artifacts'] if v['id']==a.artifact_id)
    require(a.archive.stat().st_size==record['size_in_bytes'] and 'sha256:'+digest(a.archive)==record['digest'], 'Original GitHub artifact differs')
    require(not a.output.exists(),'Refuse overwriting original artifact observation')
    if os.name=='nt':a.extract=Path('\\\\?\\'+str(a.extract.resolve()))
    a.extract.mkdir(exist_ok=True);members={}
    with zipfile.ZipFile(a.archive) as z:
        require(z.testzip() is None,'Actual original artifact CRC failure')
        for item in z.infolist():
            path=PurePosixPath(item.filename)
            require(not path.is_absolute() and '..' not in path.parts and '\\' not in item.filename and ':' not in item.filename and
                    not stat.S_ISLNK(item.external_attr>>16) and item.filename not in members,'Unsafe or repeated actual member')
            raw=z.read(item);sha=hashlib.sha256(raw).hexdigest();members[item.filename]=dict(bytes=len(raw),sha256=sha)
            target=a.extract.joinpath(*path.parts);target.parent.mkdir(parents=True,exist_ok=True)
            if item.is_dir():target.mkdir(exist_ok=True)
            elif target.exists():require(digest(target)==sha,'Existing artifact extraction differs')
            else:
                with target.open('xb') as f:f.write(raw)
    root=a.extract;projection=read(root/'COMPILED_PROJECTION_V1.json')
    def bundle(q):
        entry=projection[q['build_root']];path=root/entry['archive_prefix']
        require(digest(path/'BUILD.json')==entry['actual_BUILD_sha256'],'Actual compiled projection differs')
        return path
    cohort=root/'groundwater-clock';q=read(cohort/'RESULT.json')
    require(q['status']=='ACTUAL_GROUNDWATER_CDE_CLOCK_COMPOSITION_COHORT_PASS' and len(q['cases'])==6,'Actual original portable cohort incomplete')
    result={}
    for name in q['cases']:
        case=cohort/name;report=read(case/'RESULT.json');result[name]=audit(case,bundle(report),case/'input')
    full=root/'groundwater-clock-full';report=read(full/'RESULT.json')
    result['full']=audit(full,bundle(report),cohort/'h2-periodic/input')
    sources=source_custody(root)
    out=dict(status='ORIGINAL_UBUNTU_GROUNDWATER_CLOCK_SIX_SHORT_FULL1096_INDEPENDENT_PASS',
        origin_run=44682712004,origin_source='5c0e2b34358940e02ae6f486f04e0f262df1c040',
        original_archive=a.archive.name,sha256=digest(a.archive),artifact=record,members=members,
        science=result,source_custody=sources,whole_job_conclusion='FAILURE',
        failure_role='Missing parent output directory at first controls launch after completed and independently audited6short/full science; no control workers started',
        fresh_models=0,whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    a.output.write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8');print(out['status'])


if __name__=='__main__':main()
