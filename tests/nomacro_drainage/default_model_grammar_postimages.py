"""Target three existing state owners with original +0001 input spellings."""
import argparse
from contextlib import ExitStack
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import types
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import original_output_matrix as thermal
from model7_search_science import Store,SHA
from original_output_baseline import assignment
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence
from implicit_conductivity_forensics import output_records
from water_snow_groundwater_period import cold
m=thermal.m


class OriginalStore(Store):
    def get(self,name):
        item=self.names[name];raw=self.z.read(name)
        assert SHA(raw)==(item if isinstance(item,str) else item['sha256'])
        assert len(raw)==(self.z.getinfo(name).file_size if isinstance(item,str) else item['bytes'])
        return raw


def baseline(proof,opt,stack):
    prior=OriginalStore(proof,'HYDRAULIC_MODEL7_UNSELECTED_WINDOWS_RAW_V1',stack)
    q=json.loads(prior.get(f'profiles/model7-unselected-postimages-{opt}-v4/RESULT.json'))
    compiled=json.loads(prior.get('COMPILED_PROJECTION_V1.json'));inputs=json.loads(prior.get('INPUT_PROJECTION_V1.json'))
    results=[]
    primary=OriginalStore(proof,f'GROUNDWATER_WATER_WINDOWS_{opt}_RAW_ARCHIVE',stack)
    composition=OriginalStore(proof,f'GROUNDWATER_WATER_COMPOSITION_WINDOWS_{opt}_RAW_ARCHIVE',stack)
    prefix=f'groundwater-water-windows-{opt}-v1/short-explicit-history-step'
    results.append(('groundwater-explicit-history-step',primary.view(prefix+'/input'),composition.view(f'groundwater-water-canonical-composition-{opt}-v1/explicit-history-step/build'),primary.view(prefix+'/trajectory'),dict(input_archive=f'GROUNDWATER_WATER_WINDOWS_{opt}_RAW_ARCHIVE',input_prefix=prefix+'/input',build_archive=f'GROUNDWATER_WATER_COMPOSITION_WINDOWS_{opt}_RAW_ARCHIVE',build_prefix=f'groundwater-water-canonical-composition-{opt}-v1/explicit-history-step/build',trajectory_archive=f'GROUNDWATER_WATER_WINDOWS_{opt}_RAW_ARCHIVE',trajectory_prefix=prefix+'/trajectory')))
    for key,label in (('water-groundwater-explicit-daily','snow-groundwater-explicit-daily'),('ordinary-snow-cde-implicit-head-clock-positive','snow-cde-implicit-head-clock')):
        v=q['profiles'][key];ib=inputs[v['input_root']]['archive_prefix'];bb=compiled[v['build_root']]['archive_prefix']
        warm='profiles/'+v['trajectory_root'].replace('\\','/').split('/evidence/',1)[1]
        assert SHA(prior.get(bb+'/BUILD.json'))==compiled[v['build_root']]['actual_BUILD_sha256']
        results.append((label,prior.view(ib),prior.view(bb),prior.view(warm),dict(archive='HYDRAULIC_MODEL7_UNSELECTED_WINDOWS_RAW_V1',input_prefix=ib,build_prefix=bb,trajectory_prefix=warm)))
    return results


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--recover-existing',type=Path);a=p.parse_args();a.output.mkdir();a.build_root.mkdir(exist_ok=True)
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),optimization=a.optimization,profiles={},fresh_full_periods=0)
    recovered={}
    if a.recover_existing:
        previous=json.loads((a.recover_existing/'RESULT.json').read_text());assert previous['status']=='FAILED'
        assert not subprocess.check_output(['git','diff',previous['source'],'HEAD','--','app','src','tools/solute','tools/vq','reference'],cwd=ROOT)
        recovered=previous['profiles'];q['original_failed_observer']=dict(path=str(a.recover_existing/'RESULT.json'),sha256=SHA((a.recover_existing/'RESULT.json').read_bytes()))
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        with ExitStack() as stack:
            for name,oldinputs,oldbuild,oldwarm,provenance in baseline(ROOT/'integration/f-ci/nomacro-complete01',a.optimization,stack):
                out=a.output/name;out.mkdir();retained=recovered.get(name)
                if retained:
                    inputs=Path(retained['input_root']);assert json.loads(json.dumps(m.e.inventory(inputs)))==retained['input_inventory']
                else:
                    inputs=out/'input';inputs.mkdir()
                    for file in oldinputs.glob('*'):
                        assert file.is_file();(inputs/file.name).write_bytes(file.read_bytes())
                    path=inputs/'swap.swp';text=path.read_text(encoding='cp1252')
                    text=assignment(text,'iHWCKmodel','+0001') if re.search(r'(?mi)^\s*iHWCKmodel\s*=',text) else text+'\niHWCKmodel = +0001\n'
                    path.write_text(text,encoding='cp1252')
                project=m.e.load(inputs,original_output=True,time_step_policy='original-adaptive-day-seed-v1');build=a.build_root/name/'bundle'
                item=q['profiles'][name]=dict(status='RUNNING',input_root=str(inputs),build_root=str(build),baseline=provenance,literal='+0001',parsed_numeric_model=1,input_inventory=m.e.inventory(inputs));save()
                cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy','original-adaptive-day-seed-v1','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
                if retained:
                    assert retained['build_root']==str(build) and retained['build']['returncode']==0
                    item['build']=retained['build'];item['retained_actual_compilation']=True
                else:
                    start=time.perf_counter();run=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180)
                    (out/'build.stdout').write_text(run.stdout);(out/'build.stderr').write_text(run.stderr);item['build']=dict(command=cmd,returncode=run.returncode,seconds=time.perf_counter()-start);save();run.check_returncode()
                meta,_=m.validate_bundle(build,a.reference_work,project);oldmeta=json.loads((oldbuild/'BUILD.json').read_text())
                before={v.name:v.read_bytes().replace(b'\r\n',b'\n') for v in oldbuild.glob('*.f90')};after={v.name:v.read_bytes().replace(b'\r\n',b'\n') for v in build.glob('*.f90')}
                changed=[key for key in set(before)|set(after) if before.get(key)!=after.get(key)]
                item['whole_Fortran_delta']=changed;item['identity_changes']=differences(oldmeta['identity'],meta['identity']);save()
                assert not changed,changed
                assert meta['identity']['donor_objects']==oldmeta['identity']['donor_objects']
                for field in ('donor_flags','kernel_flags'):assert meta['identity'][field]==oldmeta['identity'][field]
                if 'restart_publisher.library_sha256' in item['identity_changes']:
                    checked=types.FunctionType(publisher_equivalence.__code__,dict(publisher_equivalence.__globals__,Path=lambda value:value))
                    item['publisher_equivalence']=checked(oldbuild/'restart_publish.dll',build/'restart_publish.dll')
                item['complete_Fortran']={key:SHA(value) for key,value in after.items()};item['actual_BUILD_sha256']=SHA((build/'BUILD.json').read_bytes());save()
                if retained and retained.get('trajectory',{}).get('days')==35:
                    warm=Path(retained.get('trajectory_root',str(a.recover_existing/name/'trajectory')))
                    data=m.rows(warm);assert len(data)==35;m.check(data)
                    item['trajectory']=retained['trajectory'];item['retained_actual_35day_postimage']=True
                else:
                    warm=out/'trajectory';item['trajectory'],data=m.trajectory(build,a.reference_work,project,warm,35,{2,4,30,34,35},180)
                item['trajectory_root']=str(warm);save()
                assert m.physical(data)==m.physical(m.rows(oldwarm)[:35])
                for day in (2,4,30,34,35):
                    member=f'accepted-column-1-day-{day}.zip'
                    with zipfile.ZipFile(warm/member) as actual,zipfile.ZipFile(io.BytesIO((oldwarm/member).read_bytes())) as expected:
                        for native in ('macro.bin','result.end'):assert actual.read(native)==expected.read(native)
                for filename in ('result_output.csv','result_output.bin'):
                    actual=warm/'original'/filename;expected=oldwarm/'original'/filename
                    assert actual.exists()==expected.is_file()
                    if actual.exists():
                        values=output_records(actual.read_bytes(),filename);assert values==output_records(expected.read_bytes(),filename)[:len(values)]
                item['cold']=[]
                for first,last in ((2,4),(30,34)):
                    item['cold'].append(cold(build,a.reference_work,project,warm,data,first,last,out/('own-'+str(first))));save()
                item['status']='ACTUAL_SIGNED_DEFAULT1_COMPLETE_COMPILED_FORTRAN_PROVIDER_PHYSICAL_NATIVE_USER_OUTPUT_SHORT_COLD_PASS_NOT_ADMITTED';save();print(name,item['status'],flush=True)
        q['status']='THREE_ACTUAL_DEFAULT_MODEL_STATE_OWNER_POSTIMAGES_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
