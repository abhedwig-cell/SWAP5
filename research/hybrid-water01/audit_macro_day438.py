"""Independently read preserved day438 observation; no model launch or rebuild."""
import argparse
import hashlib
import json
from pathlib import Path
import tarfile
import zipfile

ROOT=Path(__file__).resolve().parents[2]


def digest(raw):return hashlib.sha256(raw).hexdigest()


def physical(row):return {k:v for k,v in row.items() if k!='revision'}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--artifact',type=Path,required=True)
    p.add_argument('--metadata',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    meta=json.loads(a.metadata.read_text())
    assert 'sha256:'+digest(a.artifact.read_bytes())==meta['digest']
    assert meta['workflow_run']['head_sha']=='fe11b65305189d10f210c59da6622ace5648c4df'
    with zipfile.ZipFile(ROOT/'research/hybrid-water01/original-macro-481-evidence.zip') as proof:
        import io
        with zipfile.ZipFile(io.BytesIO(proof.read('segments/4/artifact.zip'))) as segment:
            expected={x['day']:x for x in map(json.loads,segment.read('resume-304-to-481/daily.jsonl').decode().splitlines())}
            origin=digest(segment.read('resume-304-to-481/accepted-column-1-day-432.zip'))
    with zipfile.ZipFile(a.artifact) as z:
        r=json.loads(z.read('RESULT.json'))
        assert r['status']=='PARENT_TRAJECTORY_AND_COMPLETE_NATIVE_EXACT_SHADOW_OBSERVED'
        assert r['origin_package_sha256']==origin
        assert r['observation_identity']['script_sha256']==digest((ROOT/'research/hybrid-water01/probe_macro_day438.py').read_bytes().replace(b'\r\n',b'\n'))
        assert r['observation_identity']['executable_sha256']==digest(z.read('observed-build/day_donor'))
        assert r['observation_identity']['headcalc_sha256']==digest(z.read('observed-build/headcalc.f90'))
        assert r['observation_identity']['c_sha256']==digest(z.read('observed-build/shadow.c'))
        provider=ROOT/'research/hybrid-water01/hybrid-hupsel-linux-20261111.tar.xz'
        assert digest(provider.read_bytes())=='feaec2daeada9b5f01f0391352a7b15910f406c4a0034123e65c58418cd67bde'
        with tarfile.open(provider) as t:
            index=json.load(t.extractfile('PROOF_INDEX.json'));reference=index['reference']
            for name,sha in r['original_build']['identity']['donor_objects'].items():
                assert digest(t.extractfile(reference+'/build/swap-obj/'+name).read())==sha
            assert digest(t.extractfile(reference+'/build/ttutil-obj/libttutil.a').read())==r['original_build']['identity']['ttutil_library']
        for label in ('control','observation'):
            rows=list(map(json.loads,z.read(label+'/daily.jsonl').decode().splitlines()))
            assert [x['day'] for x in rows]==list(range(433,439))
            assert all(physical(x)==physical(expected[x['day']]) for x in rows)
            for name,sha in r['complete_raw_endpoint_hashes'].items():
                assert sha==digest(z.read(label+'/original/'+name))
        raw=z.read('observation/original/day438-shadow.txt').decode()
        assert raw.splitlines()==r['shadow_records']
    records={}
    for line in raw.splitlines():
        key,*values=line.split();assert key not in records;records[key]=values
    stage,start,dt,nn,bottom,iterations,*flags=records['META']
    assert int(stage)==1 and int(nn)==112 and int(bottom)==3
    assert flags==['T','T','T','0']
    oldmax,oldsum,local_guard,total_guard=map(float,records['BEFORE'])
    newmax,newsum,maxdelta=map(float,records['AFTER'])
    old=list(map(float,records['OLD_F']));new=list(map(float,records['NEW_F']))
    assert len(old)==len(new)==112
    assert max(map(abs,old))==oldmax and max(map(abs,new))==newmax
    assert oldmax<local_guard and abs(oldsum)<total_guard
    assert newmax>local_guard and abs(newsum)>total_guard
    assert all(not x['expired'] and x['seconds']<20 for x in r['runs'])
    result={'status':'CACHED_ACCEPTED_RESIDUAL_INCONSISTENT_WITH_FRESH_ORIGINAL_OPERATOR',
        'source':meta['workflow_run']['head_sha'],'run':43167302507,'job':131012065925,
        'artifact_sha256':digest(a.artifact.read_bytes()),'original_origin432_sha256':origin,
        'window':[432,438],'parent_physical_days_exact':list(range(433,439)),
        'complete_raw_endpoint_exact':r['complete_raw_endpoint_hashes'],
        'accepted_branch':'converged, not continue-without-convergence',
        'all_three_flunsatok_flags':True,'macro_rate_reduction_level':0,
        'time1900_start':float(start),'dt_days':float(dt),'dt_seconds':float(dt)*86400,
        'iterations':int(iterations),'cached_Fmax':oldmax,'cached_Fsum':oldsum,
        'original_local_guard':local_guard,'original_total_guard':total_guard,
        'fresh_Fmax':newmax,'fresh_Fsum':newsum,'maximum_delta_F':maxdelta,
        'local_guard_ratio':newmax/local_guard,'total_guard_ratio':abs(newsum)/total_guard,
        'fresh_exceeding_nodes':sum(abs(v)>local_guard for v in new),
        'worst_node_one_based':max(range(len(new)),key=lambda i:abs(new[i]))+1,
        'runs':r['runs'],'new_models_by_auditor':0,
        'decision':'A converged frozen residual does not satisfy a refreshed original coupled residual on the identical state. Do not qualify pressure from daily mass closure. This falsifies final-step continue-without-convergence as the explanation for this observed endpoint.',
        'limits':'Single final step, not complete attribution of79.511cm, not an independently qualified reference, no repaired physics or all-timestep verdict. Fork refresh changes only child; exact native parent control qualifies observation noninterference, not scientific equivalence.',
        'next':'Use explicit frozen start-of-step state and consistent larger coupled solve in a bounded corrective work unit; do not repeat failed fresh-residual polishing campaigns or change tolerances.'}
    a.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('status','fresh_Fmax','local_guard_ratio','worst_node_one_based','new_models_by_auditor')}))


if __name__=='__main__':main()
