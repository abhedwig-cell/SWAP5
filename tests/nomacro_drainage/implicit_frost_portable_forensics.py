"""Independently read actual implicit Frost artifact bytes without path rebinding."""
import argparse
from datetime import date,timedelta
from decimal import Decimal,localcontext
import hashlib
import io
import json
import math
from pathlib import Path
import re
import struct
import subprocess
import zipfile
from frost_cde_drainage_portable_forensics import binary
from implicit_frost_boundary_forensics import audit as boundary_audit

ROOT=Path(__file__).resolve().parents[2]
PRODUCER='a6e37763a689716ec505d5f5f71dda0e94667014'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


class ArchivePath:
    def __init__(self,archive,name):self.archive,self.name=archive,name
    def __truediv__(self,name):return ArchivePath(self.archive,self.name+'/'+str(name))
    def read_bytes(self):return self.archive.read(self.name)
    def read_text(self,encoding='utf-8'):return self.read_bytes().decode(encoding)
    def exists(self):return self.name in self.archive.namelist()


def audit(archive,opt):
    read=lambda name:json.loads(archive.read(name))
    prefix='implicit-frost-root2'
    campaign=read(prefix+'/RESULT.json')
    assert campaign['source']==PRODUCER and campaign['optimization']==opt
    assert campaign['status']=='ACTUAL_PORTABLE_IMPLICIT_FROST_ROOT2_COMPONENTS_MODELS_CONTROLS_PASS_NOT_ADMITTED'
    assert len(campaign['steps'])==14 and all(step['status']=='PASS' and step['returncode']==0 for step in campaign['steps'])
    prepared=read('provider-PREPARED.json')
    assert prepared['source_archives']==dict({'SWAP.ZIP':'1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151','TTUTIL.ZIP':'ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193'})
    # Original provider dependency bytes, rather than only producer declarations.
    for name,digest in prepared['provider_files'].items():
        if name.startswith('build/'):
            assert SHA(archive.read('original-provider-build/'+name[6:]))==digest,name
    manifest=read('source/RESULT.json');assert manifest['producer_head']==PRODUCER
    capsule=archive.read('source/actual-producer-source.zip');assert SHA(capsule)==manifest['sha256']
    entries=subprocess.check_output(['git','ls-tree','-r',PRODUCER],cwd=ROOT,text=True)
    git_blobs={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in entries.splitlines()}
    with zipfile.ZipFile(io.BytesIO(capsule)) as source:
        for name in source.namelist():
            value=source.read(name);item=manifest['members'][name]
            assert SHA(value)==item['sha256'] and item['git_blob']==git_blobs[name]
            blob=lambda raw:hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
            assert git_blobs[name] in (blob(value),blob(value.replace(b'\r\n',b'\n'))),name
        projection=read('COMPILED_PROJECTION_V1.json');observations=[]
        for kind in ('water','cde'):
            controls=read(prefix+'/'+kind+'-controls/RESULT.json')
            assert controls['status']=='ACTUAL_IMPLICIT_FROST_COMPILED_NATIVE_ACTIVE_TRANSACTIONS_SCOPE_SOURCE_CONTROLS_PASS'
            assert len(controls['native_refusals'])==(39 if kind=='water' else 44)
            assert all(item['status']=='REFUSED' and 'ERROR STOP' in item['diagnostic'] for item in controls['native_refusals'])
            assert len(controls['descriptor_refusals'])==7
            assert len(controls['source_refusals'])==(6 if kind=='water' else 8)
            assert all(item['status']=='REFUSED' for item in controls['descriptor_refusals']+controls['source_refusals'])
            assert controls['transactions']['start_day']==19
            assert all(value is True for key,value in controls['transactions'].items() if key!='start_day')
            for filename in ('EXPLICIT_PARENT_CODEC_NEGATIVE.json','INDEPENDENT_SOURCE_PARENT_NEGATIVES.json'):
                value=read(prefix+'/'+kind+'-controls/'+filename)
                assert all(item['status']=='REFUSED' for item in (value if isinstance(value,list) else [value]))
            roots=read(prefix+'/'+kind+'-root-native-controls/RESULT.json')
            assert roots['status']=='ACTUAL_COMPILED_IMPLICIT_FROST_ROOT_NATIVE_REFUSALS_PASS'
            assert roots['expected_compiled_refusals']==len(roots['refusals'])==25 and roots['accepted_model_days']==0
            assert all(item['status']=='REFUSED' and item['authority']=='compiled_native' and 'ERROR STOP' in item['diagnostic'] for item in roots['refusals'])
            for phase in ('short','full'):
                location=prefix+'/'+kind+'-'+phase;profile=read(location+'/RESULT.json')
                assert profile['source']==PRODUCER and profile['kind']==kind and profile['optimization']==opt and profile['phase']==phase
                assert profile['status']=='CANDIDATE_ACTUAL_FROST_SWDIVD1_'+kind.upper()+'_'+phase.upper()+'_PASS_NOT_ADMITTED'
                projection_entry=projection[profile['build_root']];bundle=projection_entry['archive_prefix']
                raw=archive.read(bundle+'/BUILD.json');assert SHA(raw)==projection_entry['actual_BUILD_sha256']==profile['trajectory']['build_sha256']
                meta=json.loads(raw);identity=meta['identity']
                assert '-'+opt in identity['donor_flags'] and '-'+opt in identity['kernel_flags']
                assert identity['compiler_sha256']==prepared['toolchain']['gfortran']['sha256']
                assert identity['implicit_conductivity']['implicit_frost_composition'] is True
                assert identity['implicit_conductivity']['examined_ksat_interpolation'] is False
                for name,digest in identity['donor_generated'].items():assert SHA(archive.read(bundle+'/'+name))==digest
                for name,digest in identity['donor_objects'].items():assert digest==prepared['provider_files']['build/swap-obj/'+name]
                for name,digest in identity['donor_modules'].items():assert digest==prepared['provider_files']['build/swap-obj/'+name]
                for name,digest in identity['ttutil_modules'].items():assert digest==prepared['provider_files']['build/ttutil-obj/'+name]
                assert identity['ttutil_library']==prepared['provider_files']['build/ttutil-obj/libttutil.a']
                composition=identity['frost_drainage_composition']
                assert composition['native_codec']==('S5FIC002' if kind=='cde' else 'S5FIW002')
                assert composition['root_diagnostic_carry']['bytes']==96 and composition['root_diagnostic_carry']['native_revision']==2
                for name,digest in composition['providers'].items():assert SHA(source.read('app/hybrid_water/'+name).replace(b'\r\n',b'\n'))==digest
                for role,digest in meta['executable_sha256'].items():assert SHA(archive.read(bundle+'/day_'+role))==digest
                inputs=profile['input_root'].split('/proof/',1)[1]
                for name,digest in profile['inventory'].items():assert SHA(archive.read(inputs+'/'+name))==digest
                text=archive.read(inputs+'/swap.swp').decode('cp1252')
                for key,value in [('SWKIMPL',1),('SWMACRO',0),('SWFROST',1),('SWBOTB',6),('SWSOLU',int(kind=='cde'))]:
                    assert re.findall(r'(?mi)^\s*'+key+r'\s*=\s*([^\s!]+)',text)==[str(value)]
                warm=location+'/trajectory';rows=[json.loads(line,parse_float=Decimal) for line in archive.read(warm+'/daily.jsonl').decode().splitlines()]
                days=35 if phase=='short' else 1096;assert len(rows)==days
                water=Decimal(0);chemical=Decimal(0);chemical_prefix=Decimal(0);water_prefix=Decimal(0)
                with localcontext() as context:
                    context.prec=80;chemflows=[Decimal(0)]*6;waterflows=[Decimal(0)]*len(rows[0]['external_flux_cm'])
                    for day,row in enumerate(rows,1):
                        assert row['day']==day and row['committed'] is True
                        flux=row['external_flux_cm'];residual=sum(row['stock_start_cm'])-sum(row['stock_end_cm'])+sum(flux[:7])-sum(flux[7:])
                        water=max(water,abs(residual));assert abs(residual)<=Decimal('1e-10')
                        waterflows=[a+b for a,b in zip(waterflows,flux)]
                        water_prefix=max(water_prefix,abs(sum(rows[0]['stock_start_cm'])-sum(row['stock_end_cm'])+sum(waterflows[:7])-sum(waterflows[7:])))
                        if kind=='cde':
                            ledger=row['solute_ledger_mg_cm2'];residual=row['solute_end_mg_cm2']-row['solute_start_mg_cm2']-sum(ledger[2:5])+sum(ledger[5:8])
                            chemical=max(chemical,abs(residual));assert abs(residual)<=Decimal('1e-10')
                            chemflows=[a+b for a,b in zip(chemflows,ledger[2:8])]
                            residual=row['solute_end_mg_cm2']-rows[0]['solute_start_mg_cm2']-sum(chemflows[:3])+sum(chemflows[3:])
                            chemical_prefix=max(chemical_prefix,abs(residual));assert abs(residual)<=Decimal('1e-10')
                stdout=archive.read(warm+'/original/donor.stdout').decode()
                witness=[list(map(float,line.split()[1:])) for line in stdout.splitlines() if line.startswith('HYBRID_FROST_WITNESS ')]
                assert len(witness)==days+1 and all(row[-1]==1 for row in witness[1:]) and 0<witness[20][0]<1
                rates={}
                for line in stdout.splitlines():
                    if line.startswith('HYBRID_FROST_ROOT_NATIVE '):
                        clock,a,b=map(float,line.split()[1:]);rates.setdefault(clock,set()).add((a,b))
                windows=3 if phase=='short' else 7;assert len(profile['own'])==windows
                actual_output=binary(archive.read(warm+'/original/result_output.bin'))
                for own in profile['own']:
                    start,end=own['start'],own['end'];cold=location+'/own-'+str(start)
                    with zipfile.ZipFile(io.BytesIO(archive.read(warm+f'/accepted-column-1-day-{end}.zip'))) as a,zipfile.ZipFile(io.BytesIO(archive.read(cold+f'/accepted-column-1-day-{end}.zip'))) as b:
                        for name in ('macro.bin','result.end'):assert a.read(name)==b.read(name)
                        native=a.read('macro.bin');assert native[:8]==composition['native_codec'].encode()
                        header=struct.unpack('<16i',native[-96:-32]);values=struct.unpack('<4d',native[-32:])
                        expected=[4,meta['project']['nodes'],int(kind=='cde'),1,2,6,1,0]
                        assert list(header[:8])==list(header[8:])==expected
                        assert values[:2]==values[2:] and all(map(math.isfinite,values))
                        assert rates.get(identity['original_output']['original_output_epoch']+end)=={values[:2]}
                    first=date.fromisoformat(meta['project']['start_date']);low,high=str(first+timedelta(days=start)),str(first+timedelta(days=end))
                    expected=[row for row in actual_output[1:] if low<=row[:19].decode().strip()<high]
                    assert binary(archive.read(cold+'/original/result_output.bin'))[1:]==expected
                observations.append(dict(kind=kind,phase=phase,days=days,cold_windows=windows,water_max_decimal=str(water),CDE_max_decimal=str(chemical),CDE_prefix_max_decimal=str(chemical_prefix),extra_absolute_global_water_prefix=str(water_prefix),extra_global_water_prefix_is_owning_acceptance_gate=False))
    boundary=boundary_audit(ArchivePath(archive,prefix+'/boundary'))
    from implicit_frost_root_forensics import audit as root_audit
    root=root_audit(archive.read,prefix+'/root',opt,prepared)
    return dict(status='INDEPENDENT_PORTABLE_IMPLICIT_FROST_NATIVE2_RAW_SCIENCE_SOURCE_CONTROLS_PASS',producer=PRODUCER,optimization=opt,observations=observations,boundary=boundary,root_provider=root,compiled_native_refusals=135,transaction_contexts=2,model_executions=0,compiler_executions=0,canonical_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('artifact','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=p.parse_args();assert not a.output.exists()
    with zipfile.ZipFile(a.artifact) as archive:result=audit(archive,a.optimization)
    result['artifact_sha256']=SHA(a.artifact.read_bytes())
    a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(result['status'])
