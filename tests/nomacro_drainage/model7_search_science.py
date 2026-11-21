"""Read original model7 raw archives at immutable locations, without replay."""
from contextlib import ExitStack
import hashlib
import io
import itertools
import json
from pathlib import Path
import subprocess
import zipfile
from frost_cde_drainage_science import View
from hydraulic_saturation_read import inspect
from model7_capacity_forensics import audit

ROOT=Path(__file__).resolve().parents[2]
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
SURFACE=('app','src','tools/solute','tools/vq','reference/swap-4.3.1')
RUNTIME='46c2c1c74'


class Store:
    def __init__(self,proof,name,stack):
        q=json.loads((proof/(name+'.json')).read_text());path=proof/q['archive']
        assert path.stat().st_size==q['bytes'] and SHA(path.read_bytes())==q['sha256']
        self.z=stack.enter_context(zipfile.ZipFile(path));self.names=q['members']
        assert len(self.z.namelist())==len(set(self.z.namelist()))==len(self.names) and set(self.z.namelist())==set(self.names)
    def get(self,name):
        raw=self.z.read(name);item=self.names[name]
        assert SHA(raw)==item['sha256'] and len(raw)==item['bytes'];return raw
    def view(self,name):return View(self,name)


def source(store,prefix):
    manifest=json.loads(store.get(prefix+'/RESULT.json'));raw=store.get(prefix+'/actual-producer-source.zip')
    assert len(raw)==manifest['bytes'] and SHA(raw)==manifest['sha256']
    assert not subprocess.check_output(['git','diff',RUNTIME,manifest['producer_head'],'--',*SURFACE],cwd=ROOT)
    entries=subprocess.check_output(['git','ls-tree','-r',manifest['producer_head']],cwd=ROOT,text=True)
    blobs={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in entries.splitlines()}
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        for name in z.namelist():
            value=z.read(name);item=manifest['members'][name];assert SHA(value)==item['sha256']
            actual=blobs[name]
            assert actual==item['git_blob']
            blob=lambda b:hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
            assert actual in (blob(value),blob(value.replace(b'\r\n',b'\n')))
    return manifest['producer_head']


def grid(original,corrected):
    def rows(folder):
        q=json.loads((folder/'RESULT.json').read_text());assert q['status']=='ACTUAL_ORIGINAL_HYDRAULIC_INTERFACES_OBSERVED_NO_ADMISSION'
        assert q['original_models'][0]['returncode']==0 and not (folder/'model7.stderr').read_bytes()
        result={}
        for line in (folder/'model7.stdout').read_text().splitlines():
            if not line.startswith('ACTUAL_ORIGINAL_HYDRAULIC '):continue
            parts=line.split();assert len(parts)==17;key=tuple(map(int,parts[1:7]));assert key not in result;result[key]=list(map(float,parts[7:]))
        assert set(result)==set(itertools.product([7],[1,2],range(4),range(1,4),range(1,6),range(1,4)))
        return result
    before,after=rows(original),rows(corrected);old_fail=0;new_fail=0;maximum=0
    for key,a in before.items():
        b=after[key]
        for i in (0,1,3,5,6,7,8,9):assert a[i]==b[i]
        for values,is_new in ((a,False),(b,True)):
            fd=(values[6]-values[5])/(2*values[9]);error=abs(values[2]-fd)/max(abs(values[2]),abs(fd),1e-12)
            if is_new:maximum=max(maximum,error);new_fail+=int(error>2e-6)
            else:old_fail+=int(error>2e-6)
    assert old_fail==216 and new_fail==0
    return dict(states=360,retained_original_mismatches=old_fail,corrected_mismatches=new_fail,max_scaled_capacity_derivative_error=maximum,
        water_and_conductivity_values_exact=True,finite_difference_diagnostic_bound=2e-6)


def read(proof):
    results=[];components={};controls=[];sources={}
    with ExitStack() as stack:
        windows=Store(proof,'HYDRAULIC_MODEL7_SEARCH_WINDOWS_RAW_V1',stack)
        provider=Store(proof,'FROST_IMPLICIT_WINDOWS_SUPPORT_RAW_ARCHIVE',stack)
        sources['Windows']=source(windows,'profiles/model7-search-actual-source-v1')
        projection=json.loads(windows.get('COMPILED_PROJECTION_V1.json'))
        reference=provider.view('original-provider-build')
        # Keep the public path convention without copying original provider bytes.
        class Reference:
            def __truediv__(self,name):
                assert name=='build' or name.startswith('build/')
                return reference if name=='build' else reference/name[6:]
        for opt in ('O0','O2'):
            components['Windows-'+opt]=dict(saturation=inspect(windows.view('profiles/hydraulic-saturation-matrix-'+opt+'-v1')))
            for kind in ('water','cde'):
                for phase in ('short','full'):
                    profile=windows.view(f'profiles/model7-search-daily-{kind}-{phase}-{opt}-v1');q=json.loads((profile/'RESULT.json').read_text())
                    item=projection[q['build_root']];build=windows.view(item['archive_prefix']);assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
                    inputs=windows.view('profiles/'+q['input_root'].replace('\\','/').split('/evidence/',1)[1])
                    results.append(dict(platform='Windows',**audit(profile,Reference(),locations=dict(build=build,inputs=inputs))))
                controls.append(json.loads(windows.get(f'profiles/model7-search-controls-{kind}-{opt}-v1/RESULT.json')))
        for opt in ('O0','O2'):
            current=Store(proof,'HYDRAULIC_MODEL7_SEARCH_UBUNTU_'+opt+'_RAW_V1',stack)
            sources['Ubuntu-'+opt]=source(current,'source')
            prefix='model7-capacity-search/';top=json.loads(current.get(prefix+'RESULT.json'))
            assert top['status']=='ACTUAL_MODEL7_PORTABLE_COMPONENT_FULL_MODELS_NATIVE_CONTROLS_PASS_NOT_ADMITTED' and top['producer']==sources['Ubuntu-'+opt]
            projection=json.loads(current.get('COMPILED_PROJECTION_V1.json'))
            reference=current.view('original-provider-build')
            components['Ubuntu-'+opt]=dict(saturation=inspect(current.view(prefix+'saturation')),
                capacity_grid=grid(current.view(prefix+'capacity-grid-0'),current.view(prefix+'capacity-grid-1')))
            for kind in ('water','cde'):
                for phase in ('short','full'):
                    profile=current.view(prefix+kind+'-'+phase);q=json.loads((profile/'RESULT.json').read_text());item=projection[q['build_root']]
                    build=current.view(item['archive_prefix']);assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
                    assert q['input_root'].endswith('/'+kind+'-short/input')
                    results.append(dict(platform='Ubuntu',**audit(profile,Reference(),locations=dict(build=build,inputs=current.view(prefix+kind+'-short/input')))))
                controls.append(json.loads(current.get(prefix+kind+'-controls/RESULT.json')))
        for c in controls:
            assert c['status']=='ACTUAL_MODEL7_EXISTING_NATIVE_COMPILED_REFUSALS_ACTIVE_TRANSACTIONS_PASS_NOT_ADMITTED'
            assert all(item['status']=='REFUSED' and 'ERROR STOP' in item['diagnostic'] for item in c['native_refusals'])
        assert len(results)==16 and sum(r['days']==1096 for r in results)==8
    return dict(status='ACTUAL_MODEL7_WINDOWS_UBUNTU_RAW_SCIENCE_INDEPENDENT_PASS_NO_ADMISSION',results=results,components=components,
        sources=sources,compiled_native_refusals=sum(len(c['native_refusals']) for c in controls),active_transaction_contexts=len(controls),
        full1096_contexts=8,short35_contexts=8,exact_cold_windows=sum(r['cold_windows'] for r in results),public_admission=False,whole_historical_family_closed=False,
        canonical_push_preservation_failures='Retained separate DATAQUAL12 unreviewed-delta gate failures; no successful replay claimed.')


if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
    result=read(a.proof);a.output.write_text(json.dumps(result,indent=2)+'\n');print(result['status'],result['exact_cold_windows'],result['compiled_native_refusals'])
