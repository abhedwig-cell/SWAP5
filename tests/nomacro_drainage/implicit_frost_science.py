"""Read neutral implicit Frost archives without changing any producer binding."""
import ast
from contextlib import ExitStack
from datetime import date,timedelta
from decimal import Decimal,localcontext
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import subprocess
import zipfile
from frost_cde_drainage_science import Archives,View,Bytes,mapped
import frost_cde_drainage_model_forensics as original
from frost_cde_drainage_portable_forensics import binary
from implicit_frost_boundary_forensics import audit as boundary_audit

ROOT=Path(__file__).resolve().parents[2]
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
RUNTIME='664596939f699ddbf0ebbdfdcfedcd37c5cc60e7'
READERS='b285147254b208643423adea88a4fb5f1158b464'


class ReadView(View):
    def __truediv__(self,name):return ReadView(self.store,self.path+'/'+str(name))
    def exists(self):return self.is_file()


def frozen_model():
    path='tests/nomacro_drainage/frost_cde_drainage_model_forensics.py'
    raw=subprocess.check_output(['git','show',READERS+':'+path],cwd=ROOT)
    assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==raw
    functions=[node for node in ast.parse(raw.decode()).body if isinstance(node,ast.FunctionDef) and node.name=='audit']
    assert len(functions)==1
    class Codec(ast.NodeTransformer):
        changes=0
        def visit_Constant(self,node):
            replacements={b'S5FDW001':b'S5FIW002',b'S5FDC001':b'S5FIC002'}
            if isinstance(node.value,bytes) and node.value in replacements:
                self.changes+=1;return ast.copy_location(ast.Constant(replacements[node.value]),node)
            return node
    change=Codec();function=change.visit(functions[0]);assert change.changes==2
    namespace=dict(vars(original));exec(compile(ast.fix_missing_locations(ast.Module(body=[function],type_ignores=[])),path,'exec'),namespace)
    return namespace['audit']


def windows(proof):
    with ExitStack() as stack:
        labels=['WINDOWS_'+opt+'_'+kind for opt in ('O0','O2') for kind in ('SCIENCE','CONTROLS')]+['WINDOWS_SUPPORT']
        current=Archives(proof,'FROST_IMPLICIT_',labels,stack)
        projection=json.loads(current.get('COMPILED_PROJECTION_V1.json'))
        prepared=json.loads(current.get('provider-PREPARED.json'))
        for name,digest in prepared['provider_files'].items():
            if name.startswith('build/'):assert SHA(current.get('original-provider-build/'+name[6:]))==digest
        manifest=json.loads(current.get('profiles/frost-implicit-actual-source-capsule-v1/RESULT.json'))
        raw=current.get('profiles/frost-implicit-actual-source-capsule-v1/actual-producer-source.zip')
        assert SHA(raw)==manifest['sha256'] and len(raw)==manifest['bytes']
        assert not subprocess.check_output(['git','diff',RUNTIME,manifest['producer_head'],'--','app','src','tools/solute','tools/vq','reference/swap-4.3.1'],cwd=ROOT)
        source=stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)))
        entries=subprocess.check_output(['git','ls-tree','-r',manifest['producer_head']],cwd=ROOT,text=True)
        blobs={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in entries.splitlines()}
        for name in source.namelist():
            raw=source.read(name);item=manifest['members'][name]
            assert SHA(raw)==item['sha256'] and item['git_blob']==blobs[name]
            blob=lambda value:hashlib.sha1(b'blob '+str(len(value)).encode()+b'\0'+value).hexdigest()
            assert blobs[name] in (blob(raw),blob(raw.replace(b'\r\n',b'\n')))
        reference=View(Bytes({'original/build/swap-selected/divdra.f90':current.get('original-provider-build/swap-selected/divdra.f90')}),'original')
        audit=frozen_model();results=[];boundaries={};roots={};controls=[]
        for opt in ('O0','O2'):
            from implicit_frost_root_forensics import audit as root_audit
            roots[opt]=root_audit(current.get,'profiles/frost-implicit-root-state-'+opt+'-v1',opt,prepared)
            boundaries[opt]=boundary_audit(ReadView(current,'profiles/frost-implicit-raw-residual-'+opt+'-v2'))
            for kind in ('water','cde'):
                for phase in ('short','full'):
                    profile=current.view('profiles/frost-implicit-root-daily-'+kind+'-'+phase+'-'+opt+'-v1')
                    q=json.loads((profile/'RESULT.json').read_text());item=projection[q['build_root']];bundle=current.view(item['prefix'])
                    assert SHA((bundle/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
                    result=audit(profile,reference,locations=dict(bundle=bundle,inputs=mapped(current,q['input_root']),warm=profile/'trajectory',cold=lambda day,p=profile:p/('own-'+str(day))),provider_catalog=prepared['provider_files'])
                    meta=json.loads((bundle/'BUILD.json').read_text());identity=meta['identity'];composition=identity['frost_drainage_composition']
                    assert identity['implicit_conductivity']['implicit_frost_composition'] is True and identity['implicit_conductivity']['examined_ksat_interpolation'] is False
                    for name,digest in composition['providers'].items():assert SHA(source.read('app/hybrid_water/'+name).replace(b'\r\n',b'\n'))==digest
                    # Invert actual complete compiled numerical bodies to already
                    # admitted ordinary-soil and explicit-Frost parents.
                    import sys
                    sys.path.insert(0,str(ROOT/'app/hybrid_water'))
                    from implicit_frost_surface_conductivity import restore
                    from implicit_frost_source_guard import TERMINAL_PARTS,EXPLICIT_FROST_TIME
                    from lower_boundary_receipt import render_headcalc
                    from ordinary_pond_source_guard import HEADS
                    text=restore((bundle/'headcalc.f90').read_text(encoding='cp1252'))
                    for part in TERMINAL_PARTS:assert text.count(part)==1;text=text.replace(part,'',1)
                    assert SHA(render_headcalc(text,8).encode('cp1252'))==HEADS['water']
                    from groundwater_snow_retry import inverse,TIME_TEMPLATE
                    from implicit_conductivity_retry import time_source
                    from implicit_pond_event import time_source as event
                    text=inverse((bundle/'timecontrol.f90').read_text(encoding='cp1252'),lambda value:event(time_source(value)),TIME_TEMPLATE)
                    assert SHA(text.encode('cp1252'))==EXPLICIT_FROST_TIME
                    from ordinary_implicit_pond_switch import actual_source
                    actual_source((bundle/'boundtop.f90').read_bytes(),True)
                    warm=profile/'trajectory';rates={}
                    for line in (warm/'original/donor.stdout').read_text().splitlines():
                        if line.startswith('HYBRID_FROST_ROOT_NATIVE '):
                            clock,a,b=map(float,line.split()[1:]);rates.setdefault(clock,set()).add((a,b))
                    output=binary((warm/'original/result_output.bin').read_bytes())
                    for own in q['own']:
                        start,end=own['start'],own['end'];cold=profile/('own-'+str(start))
                        with zipfile.ZipFile(io.BytesIO((warm/f'accepted-column-1-day-{end}.zip').read_bytes())) as archive:
                            raw=archive.read('macro.bin')
                        header=struct.unpack('<16i',raw[-96:-32]);values=struct.unpack('<4d',raw[-32:])
                        assert list(header[:8])==list(header[8:])==[4,meta['project']['nodes'],int(kind=='cde'),1,2,6,1,0]
                        assert values[:2]==values[2:] and all(map(math.isfinite,values))
                        assert rates.get(identity['original_output']['original_output_epoch']+end)=={values[:2]}
                        first=date.fromisoformat(meta['project']['start_date']);low,high=str(first+timedelta(days=start)),str(first+timedelta(days=end))
                        expected=[row for row in output[1:] if low<=row[:19].decode().strip()<high]
                        assert binary((cold/'original/result_output.bin').read_bytes())[1:]==expected
                    result['complete_numerical_parent_inverse_and_root_native_writer_verified']=True
                    rows=[json.loads(line,parse_float=Decimal) for line in (warm/'daily.jsonl').read_text().splitlines()]
                    with localcontext() as context:
                        context.prec=80;flows=[Decimal(0)]*len(rows[0]['external_flux_cm']);maximum=Decimal(0)
                        for row in rows:
                            flows=[a+b for a,b in zip(flows,row['external_flux_cm'])]
                            maximum=max(maximum,abs(sum(rows[0]['stock_start_cm'])-sum(row['stock_end_cm'])+sum(flows[:7])-sum(flows[7:])))
                    result['extra_absolute_global_water_prefix']=str(maximum);result['extra_global_water_prefix_is_owning_acceptance_gate']=False
                    results.append(result)
                version='v1' if kind=='water' else 'v2';prefix='profiles/frost-implicit-root-controls-'+kind+'-'+opt+'-'+version
                cq=json.loads(current.get(prefix+'/RESULT.json'))
                assert cq['status']=='ACTUAL_IMPLICIT_FROST_COMPILED_NATIVE_ACTIVE_TRANSACTIONS_SCOPE_SOURCE_CONTROLS_PASS'
                assert len(cq['native_refusals'])==(39 if kind=='water' else 44)
                assert all(item['status']=='REFUSED' and 'ERROR STOP' in item['diagnostic'] for item in cq['native_refusals'])
                assert len(cq['descriptor_refusals'])==7 and len(cq['source_refusals'])==(6 if kind=='water' else 8)
                assert all(item['status']=='REFUSED' for item in cq['descriptor_refusals']+cq['source_refusals'])
                assert cq['transactions']['start_day']==19 and all(value is True for key,value in cq['transactions'].items() if key!='start_day')
                for filename in ('EXPLICIT_PARENT_CODEC_NEGATIVE.json','INDEPENDENT_SOURCE_PARENT_NEGATIVES.json'):
                    value=json.loads(current.get(prefix+'/'+filename));assert all(item['status']=='REFUSED' for item in (value if isinstance(value,list) else [value]))
                root=json.loads(current.get('profiles/frost-implicit-root-native-controls-'+kind+'-'+opt+'-v1/RESULT.json'))
                assert root['status']=='ACTUAL_COMPILED_IMPLICIT_FROST_ROOT_NATIVE_REFUSALS_PASS' and len(root['refusals'])==25
                assert all(item['status']=='REFUSED' and item['authority']=='compiled_native' and 'ERROR STOP' in item['diagnostic'] for item in root['refusals'])
                controls.append(dict(kind=kind,optimization=opt,compiled_native_refusals=len(cq['native_refusals'])+26,descriptor_refusals=7,source_refusals=len(cq['source_refusals']),transaction_contexts=1))
        return dict(status='SEALED_ACTUAL_IMPLICIT_FROST_WINDOWS_RAW_SCIENCE_SOURCE_CONTROLS_PASS',results=results,boundaries=boundaries,root_providers=roots,controls=controls,actual_full_periods=4,actual_full_cold_windows=28,actual_short_contexts=4,actual_short_cold_windows=12,actual_compiled_refusals=270,actual_descriptor_refusals=28,actual_source_refusals=28,actual_transaction_contexts=4,compiler_executions=0,model_executions=0)


def ubuntu(proof,opt):
    from implicit_frost_portable_forensics import audit
    record=json.loads((Path(proof)/('FROST_IMPLICIT_UBUNTU_'+opt+'_RAW_ARCHIVE.json')).read_text())
    path=Path(proof)/record['archive'];assert path.stat().st_size==record['bytes'] and SHA(path.read_bytes())==record['sha256']
    with zipfile.ZipFile(path) as archive:result=audit(archive,opt)
    return dict(status='SEALED_ACTUAL_IMPLICIT_FROST_UBUNTU_RAW_SCIENCE_SOURCE_CONTROLS_PASS',observations=result,actual_full_periods=2,actual_full_cold_windows=14,actual_short_contexts=2,actual_short_cold_windows=6,actual_compiled_refusals=135,actual_descriptor_refusals=14,actual_source_refusals=14,actual_transaction_contexts=2,compiler_executions=0,model_executions=0)


def unselected(proof):
    from ordinary_pond_evidence import physical
    with ExitStack() as stack:
        labels=['WINDOWS_'+opt+'_'+kind for opt in ('O0','O2') for kind in ('SCIENCE','CONTROLS')]+['WINDOWS_SUPPORT']
        previous=Archives(proof,'FROST_DRAINAGE_',labels,stack)
        previous_projection=json.loads(previous.get('COMPILED_PROJECTION_V1.json'))
        observations=[]
        for opt in ('O0','O2'):
            current=Archives(proof,'FROST_IMPLICIT_',['WINDOWS_UNSELECTED_'+opt],stack)
            projection=json.loads(current.get('UNSELECTED_COMPILED_PROJECTION_V1.json'))
            profile='profiles/implicit-frost-unselected-postimages-'+opt+'-v1'
            q=json.loads(current.get(profile+'/RESULT.json'))
            assert q['status']=='ACTUAL_EIGHT_UNSELECTED_IMPLICIT_FROST_DEPENDENCY_POSTIMAGES_PASS' and len(q['profiles'])==8 and q['fresh_unaffected_full_periods']==0
            for name,item in q['profiles'].items():
                assert item['status']=='EXACT_UNSELECTED_FORTRAN_PHYSICAL_NATIVE_USER_OUTPUT_POSTIMAGE_PASS'
                base=item['baseline']
                old_entry=previous_projection[base['build_root']];new_entry=projection[item['build_root']]
                before=previous.view(old_entry['prefix']);after=current.view(new_entry['prefix'])
                assert SHA((before/'BUILD.json').read_bytes())==old_entry['actual_BUILD_sha256']
                assert SHA((after/'BUILD.json').read_bytes())==new_entry['actual_BUILD_sha256']
                old_sources={path.name:SHA(path.read_bytes()) for path in before.glob('*.f90')}
                new_sources={path.name:SHA(path.read_bytes()) for path in after.glob('*.f90')}
                assert old_sources==new_sources==item['unchanged_complete_Fortran']
                oldmeta=json.loads((before/'BUILD.json').read_text());newmeta=json.loads((after/'BUILD.json').read_text())
                assert oldmeta['inputs']==newmeta['inputs']
                warm=mapped(current,item['trajectory_root']);oldwarm=mapped(previous,base['trajectory_root']);cold=mapped(current,item['cold_actual_root'])
                rows=lambda path:[json.loads(line) for line in (path/'daily.jsonl').read_text().splitlines()]
                data,parent=rows(warm),rows(oldwarm)
                assert len(data)==35 and physical(data)==physical(parent[:35]) and physical(rows(cold))==physical(data[30:34])
                for day in (2,4,30,34,35):
                    with zipfile.ZipFile(io.BytesIO((oldwarm/f'accepted-column-1-day-{day}.zip').read_bytes())) as a,zipfile.ZipFile(io.BytesIO((warm/f'accepted-column-1-day-{day}.zip').read_bytes())) as b:
                        assert all(a.read(member)==b.read(member) for member in ('macro.bin','result.end'))
                with zipfile.ZipFile(io.BytesIO((warm/'accepted-column-1-day-34.zip').read_bytes())) as a,zipfile.ZipFile(io.BytesIO((cold/'accepted-column-1-day-34.zip').read_bytes())) as b:
                    assert all(a.read(member)==b.read(member) for member in ('macro.bin','result.end'))
                for filename in ('result_output.bin','result_output.csv'):
                    a,b=oldwarm/('original/'+filename),warm/('original/'+filename)
                    assert a.is_file()==b.is_file()
                    if a.is_file():
                        from implicit_conductivity_forensics import output_records
                        oldrows=output_records(a.read_bytes(),filename);newrows=output_records(b.read_bytes(),filename)
                        assert newrows==oldrows[:len(newrows)]
                observations.append(dict(name=name,optimization=opt,whole_generated_Fortran_input_physical_native_original_output_exact=True,cold_window=(30,34)))
        assert len(observations)==16
        return dict(status='SEALED_ACTUAL_SIXTEEN_UNSELECTED_IMPLICIT_FROST_POSTIMAGES_PASS',observations=observations,actual_unselected_contexts=16,actual_unselected_cold_windows=16,fresh_unaffected_full_periods=0,model_executions=0,compiler_executions=0)
