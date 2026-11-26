"""Fresh local physical evidence and original refusal; no model executions."""
import argparse,hashlib,io,json,tarfile,zipfile
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from frost_boundary_git_archive import GitArchiveSource
from frost_analytical_boundary_archive_science import R,P,git,read,case_audit

SCI='b24cebc3993b0f350c7aef7fb773a177d00425ce'
CURRENT='45bb6146f5800f4050e95feb5d1912ddfdd23d4d'
NEGATIVE='211faea04c2c2dd172ecbbb619e81bfce241fe68'


def capsule(store,stack):
    expected={r.split('\t',1)[1]:r.split('\t',1)[0].split()[2] for r in git('ls-tree','-r',SCI).decode().splitlines()}
    def check(name,raw,item):
        assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'] and item['git_blob']==expected[name]
        blob=lambda b:hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
        assert expected[name] in (blob(raw),blob(raw.replace(b'\r\n',b'\n')))
    q=json.loads(store.get('actual-source-B24/RESULT.json'));raw=store.get('actual-source-B24/actual-producer-source.zip')
    assert q['producer_head']==SCI and len(raw)==q['bytes'] and SHA(raw)==q['sha256']
    z=stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)));absent={n for n,i in q['members'].items() if i.get('checkout')=='ABSENT'}
    assert set(z.namelist())==set(q['members'])-absent and all(n.startswith('reference/swap-4.3.1/') for n in absent)
    for n,i in q['members'].items():
        if n in absent:assert i==dict(git_blob=expected[n],checkout='ABSENT')
        else:check(n,z.read(n),i)
    stem='actual-controller-B24/FROST_ANALYTICAL_BOUNDARY10_CONTROLLER_B24_CAPTURE_V2'
    ctl=json.loads(store.get(stem+'.json'));raw=store.get(stem+'.tar')
    assert ctl['producer_head']==SCI and len(raw)==ctl['bytes'] and SHA(raw)==ctl['sha256']
    tar=stack.enter_context(tarfile.open(fileobj=io.BytesIO(raw)));assert {m.name for m in tar.getmembers()}==set(ctl['members'])
    for n,i in ctl['members'].items():check(n,tar.extractfile(n).read(),i)
    for sha in [SCI,CURRENT,NEGATIVE]:assert store.get('genuine-commit/'+sha+'.bin')==git('cat-file','commit',sha)
    return dict(actual_scientific_source=SCI,actual_controller_source=SCI,source_sha256=q['sha256'],controller_sha256=ctl['sha256'])


def local(proof,verbose=False):
    with ExitStack() as stack:
        store=Archive(proof,'FROST_ANALYTICAL_BOUNDARY10_LOCAL_WINDOWS_O0_O2_RAW_V2',stack)
        source=capsule(store,stack);dependency=json.loads(store.get('LOCAL_PROVIDER_DEPENDENCY_V1.json'))
        provider=Archive(GitArchiveSource(R,dependency['actual_data_revision']),dependency['archive'],stack)
        assert provider.record['sha256']==dependency['sha256']
        for n,i in dependency['actual_required_files'].items():
            raw=provider.get(n);assert len(raw)==i['bytes'] and SHA(raw)==i['sha256']
        contexts=[]
        for item in store.record['contexts']:
            assert item['actual_source']==SCI
            contexts.append(case_audit(store,item['archive_prefix'],item['case'],provider,SCI,item['optimization']))
            if verbose:print('INDEPENDENT_LOCAL_SEARCH_CONTEXT_PASS',item['optimization'],item['case']['name'],flush=True)
        assert len(contexts)==6 and sum(c['case']['days'] for c in contexts)==164
        assert sum(c['native_samples'] for c in contexts)==36 and sum(c['exact_cold_windows'] for c in contexts)==16
        assert sum(c['controls']['actual_compiled_refusals'] for c in contexts)==108 and sum(len(c['controls']['transactions']) for c in contexts)==8
        old=Archive(proof,'FROST_ANALYTICAL_COMPOSITION09_LOCAL_WINDOWS_O0_O2_RAW_V1',stack)
        projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));prior_projection=json.loads(old.get('COMPILED_PROJECTION_V1.json'));postimages=[]
        for opt in ['O0','O2']:
            q=json.loads(store.get('current-old09-whole-postimages/corrected-policy-v3/'+opt+'-model7-current-postimage/RESULT.json'))
            assert q['status']=='CURRENT_ACTUAL_MODEL7_COMPLETE_GENERATED_SOURCES_SAME_COMPILER_AND_WHOLE_OBJECTS_PASS_NO_PERIOD_REPLAY'
            assert q['actual_current_source']==CURRENT and q['original_scientific_source']=='dd7596685c91074789ab56e9a3ecb3d4a4ef4b4c' and q['model_executions']==0
            prior=json.loads(old.get('current/'+opt+'-model7-7-cde-b8-p1/science/RESULT.json'))
            build=ReadView(store,projection[q['actual_build']['root']]['archive_prefix']);parent=ReadView(old,prior_projection[prior['build_root']]['archive_prefix']);meta=read(build/'BUILD.json');before=read(parent/'BUILD.json')
            assert SHA((build/'BUILD.json').read_bytes())==q['actual_BUILD_sha256'] and SHA((parent/'BUILD.json').read_bytes())==q['original_BUILD_sha256']
            assert q['original_archive_sha256']==old.record['sha256'] and meta['inputs']==before['inputs']
            for key in ['compiler','compiler_sha256','target','donor_flags','kernel_flags','donor_generated','donor_objects','donor_modules','ttutil_modules','ttutil_library']:assert meta['identity'][key]==before['identity'][key]
            for n,digest in meta['identity']['donor_generated'].items():assert (build/n).read_bytes()==(parent/n).read_bytes() and SHA((build/n).read_bytes())==digest
            objects={p.name for p in build.glob('*.o')};assert objects=={p.name for p in parent.glob('*.o')}=={i['file'] for i in q['whole_objects']} and len(objects)==27
            for i in q['whole_objects']:
                raw=(build/i['file']).read_bytes();assert raw==(parent/i['file']).read_bytes() and len(raw)==i['bytes'] and SHA(raw)==i['sha256']
            postimages.append(dict(optimization=opt,whole_objects=27,current_compiler_source=CURRENT,original_scientific_source=q['original_scientific_source'],model_replays=0))
        prefix='original-unbuffered-211-refusal/case7';negative=json.loads(store.get(prefix+'/RESULT.json'))
        assert negative['actual_source']==NEGATIVE and negative['status'].startswith('FAILED_')
        assert not git('diff','b4ffcc914453225562ffe0e847faa21a765432ce',NEGATIVE,'--','app','src','tools','reference')
        rows=[json.loads(line) for line in store.get(prefix+'/science/trajectory/daily.jsonl').splitlines()]
        assert len(rows)==33 and all(r['committed'] for r in rows[:-1]) and not rows[-1]['committed'] and abs(rows[-1]['independent_residual_cm'])>1e-10
        warnings=store.get(prefix+'/science/trajectory/original/swap.wrn');assert warnings.count(b'No convergence was reached')==4
        return dict(status='INDEPENDENT_SIX_LOCAL_SEARCH_CONTEXTS54_CURRENT_OLD09_WHOLE_OBJECTS_AND_TRUE_ORIGINAL_CONVERGENCE_REFUSAL_PASS_NOT_ADMITTED',source=source,contexts=contexts,old09_postimages=postimages,original_negative_source=NEGATIVE,original_negative_receipt=rows[-1],original_unconverged_warnings=4,compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();head=git('rev-parse','HEAD').decode().strip();q=dict(actual_observer=head)
    try:q['audit']=local(GitArchiveSource(R,head),True);q['status']=q['audit']['status']
    except Exception as error:q.update(status='FAILED_INDEPENDENT_LOCAL_SEARCH_AUDIT',error=repr(error));raise
    finally:
        assert git('rev-parse','HEAD').decode().strip()==head
        with a.output.open('x') as out:json.dump(q,out,indent=2);out.write('\n')
    print(q['status'],flush=True)
