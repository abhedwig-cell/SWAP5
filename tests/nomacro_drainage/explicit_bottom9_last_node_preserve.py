"""Seal only the new last-node water evidence; link the unchanged central42."""
import argparse,json
from pathlib import Path
from analytical_hydraulic_archives import SHA
from initial_profile_frost_preserve import seal
from explicit_bottom9_source_inverse import ROOT,CORE,LAST_NODE_CORE,complete_inverse,git


def windows(ev,staging):
    complete_inverse();files={};projection={};roles=[]
    def tree(path,prefix):
        assert path.is_dir() and not path.is_symlink()
        for file in sorted(path.rglob('*')):
            assert not file.is_symlink()
            if file.is_file():
                key=prefix+'/'+file.relative_to(path).as_posix();assert key not in files;files[key]=file
    def build(actual):
        if actual in projection:return
        path=Path(actual);prefix='compiled/'+path.parent.name+'/bundle';tree(path,prefix)
        projection[actual]=dict(archive_prefix=prefix,actual_BUILD_sha256=SHA((path/'BUILD.json').read_bytes()))
    prefixes=('explicit-bottom9-last-node','explicit_bottom9_last_node','explicit-bottom9-water-last-node')
    for path in sorted(ev.iterdir()):
        if not path.name.lower().startswith(prefixes):continue
        if path.is_dir():tree(path,'profiles/'+path.name)
        elif path.is_file():files['observations/'+path.name]=path
    result=json.loads((ev/'EXPLICIT_BOTTOM9_LAST_NODE_WATER_O0_O2_V2.json').read_text());assert len(result['contexts'])==2
    for item in result['contexts']:
        primary=Path(item['profile']);post=Path(item['postimage']);q=json.loads((primary/'RESULT.json').read_text());p=json.loads((post/'RESULT.json').read_text())
        assert q['status']=='ACTUAL_EXPLICIT_PAIRED_HEAD_FLUX_PHYSICAL_NATIVE_EXACT_COLD_USER_OUTPUT_PASS_NOT_ADMITTED' and q['case']=='water-last-node-drainage'
        assert p['initial1_profile']==str(primary) and p['initial1_RESULT_sha256']==SHA((primary/'RESULT.json').read_bytes())
        build(q['build_root']);build(p['build_root'])
        for key in ('independent','actual_compiled'):assert SHA(Path(item[key]).read_bytes())==item[key+'_sha256']
        roles.append(dict(profile='profiles/'+primary.name,original_profile_path=str(primary),postimage='profiles/'+post.name,inputs_archive='EXPLICIT_BOTTOM9_WINDOWS_RAW_V1',inputs='profiles/'+Path(q['input_root']).relative_to(ev).as_posix(),counter_inputs='profiles/'+Path(p['input_root']).relative_to(ev).as_posix(),independent='observations/'+Path(item['independent']).name,actual_compiled='observations/'+Path(item['actual_compiled']).name,actual_producer=q['source'],optimization=q['optimization']))
    assert len(projection)==4
    links={}
    for name in ('EXPLICIT_BOTTOM9_WINDOWS_RAW_V1','EXPLICIT_BOTTOM9_UBUNTU_O0_RAW_V1','EXPLICIT_BOTTOM9_UBUNTU_O2_RAW_V1'):
        q=json.loads((ROOT/'integration/f-ci/nomacro-complete01'/(name+'.json')).read_text());links[name]=dict(bytes=q['bytes'],sha256=q['sha256'],members=len(q['members']))
    extra={key:(json.dumps(value,indent=2)+'\n').encode() for key,value in [('COMPILED_PROJECTION_V1.json',projection),('PARENT_CENTRAL_RAW_LINKS_V1.json',links)]}
    extra['actual-sealer.py']=Path(__file__).read_bytes()
    assert staging.is_dir() and not any(staging.iterdir())
    name='EXPLICIT_BOTTOM9_LAST_NODE_WINDOWS_RAW_V1'
    seal(staging/(name+'.zip'),name,files,extra,dict(status='ACTUAL_TWO_WINDOWS_LAST_NODE_WATER_RAW_NATIVE_COLD_COMPILED_SOURCE_FRONTEND_AND_FAILED_OBSERVER_PRESERVED_NOT_ADMITTED',roles=roles,input_admission_core=LAST_NODE_CORE,unchanged_physical_core=CORE,actual_runtime_sources=[i['actual_producer'] for i in roles],new_short35_contexts=2,new_native_checkpoints=14,new_exact_cold_windows=6,new_initial2_compiled_counterparts=2,prior42_raw_archives_rewritten=False,prior42_model_periods_replayed=False,sealer_source=git('rev-parse','HEAD').decode().strip(),canonical_admission=False))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--staging',type=Path,required=True);a=p.parse_args();windows(a.evidence,a.staging)
