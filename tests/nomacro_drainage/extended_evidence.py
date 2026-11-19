"""Independent raw archive audit; no production adapter or model executions."""
import argparse
from datetime import date
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import zipfile

from extended_forensics import require,geometry,inventory,observed,checkpoint
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
from perstep_domain_verify import build_files

def digest(raw):return hashlib.sha256(raw).hexdigest()
def lines(raw):return [json.loads(line) for line in raw.splitlines() if line.strip()]
def csv(raw):return [line for line in raw.decode('cp1252').splitlines() if line.strip() and not line.startswith('*')]
def physical(rows):return [{k:v for k,v in row.items() if k not in ('column','revision')} for row in rows]
def package(raw):
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        require(set(z.namelist())=={'checkpoint.json','result.end','macro.bin'},'Foreign actual control checkpoint inventory')
        meta=json.loads(z.read('checkpoint.json'));parts={n:z.read(n) for n in ('result.end','macro.bin')}
        require(set(meta['files'])==set(parts) and all(digest(parts[n])==v for n,v in meta['files'].items()),'Actual control checkpoint hashes differ')
        return meta,parts
DOMAINS=dict(prescribed=[1,34,2,3,1,1,1,1],fixed=[1,34,2,2,2,0,2,1],automatic=[1,34,2,3,2,1,1,1],water=[1,34,3,2,2,0,3,1],table=[1,34,2,2,2,0,2,1])

def period(z,prefix,case,optimization):
    read=lambda name:z.read(prefix+name)
    result=json.loads(read('RESULT.json'));build=json.loads(read('trajectory/BUILD.json'));data=lines(read('trajectory/daily.jsonl'))
    expected_days=37 if case=='table' else 1096
    require(result['case']==case and result['optimization']==optimization and result['requested_days']==expected_days and len(data)==expected_days and data[0]['day']==1,'Actual original configuration/period censored')
    require(result['public_admission'] is False and result['functional_completion']=='PARTIAL' and result['whole_scientific_equivalence']=='NOT_QUALIFIED','Producer promoted incomplete historical scope')
    require(build['project']==dict(case=build['project']['case'],model='HYBRID_NOMACRO_WATER',start_date='2002-01-01',nodes=34,water_tolerance=1e-10),'Original extended H domain/guard changed')
    require(build['identity']['extended_drainage']['domain']==DOMAINS[case] and build['identity']['extended_drainage']['codec']=='S5EDR001','Selected original native domain changed')
    require(('solute_end_mg_cm2' in data[0])==(case!='water'),'Original water/CDE composition changed')
    for name,expected in build['inputs'].items():
        require(Path(name).name==name and digest(read('input/'+name))==expected,'Original experimental input bytes changed')
    require(result['fixture']['inputs']==build['inputs'] and result['fixture']['declared_configuration']==case,'Original fixture/build identity differs')
    control=read('input/swap.swp').decode('cp1252');dz=geometry(control)
    require(len(dz)==34 and re.search(r'(?mi)^\s*SWDRA\s*=\s*2\b',control) is not None,'Original extended reader not actually selected')
    report=inventory(data);observed(read('trajectory/original/donor.stdout'),data,build)
    warm_csv=csv(read('trajectory/original/result_output.csv'));require(len(warm_csv)==len(data)+2,'Actual compatibility CSV censored')
    windows=[(2,4),(14,17),(30,35),(35,37)]
    if expected_days==1096:windows += [(363,367),(530,532),(1094,1096)]
    require([(x['start'],x['end']) for x in result['cold']]==windows,'Required actual original cold window omitted')
    cuts={expected_days,*(v for pair in windows for v in pair)}
    actual={int(name.rsplit('-',1)[1][:-4]) for name in z.namelist() if name.startswith(prefix+'trajectory/accepted-column-1-day-') and name.endswith('.zip') and '/' not in name[len(prefix+'trajectory/'): ]}
    require(actual==cuts,'Actual complete checkpoint inventory changed')
    native={day:checkpoint(read(f'trajectory/accepted-column-1-day-{day}.zip'),build,data[day-1],dz) for day in cuts}
    for low,high in windows:
        cold=f'cold-{low}/';continuation=lines(read(cold+'daily.jsonl'))
        physical=lambda values:[{k:v for k,v in row.items() if k!='revision'} for row in values]
        require(physical(continuation)==physical(data[low:high]),'Actual original cold physical receipt differs')
        inventory(continuation);observed(read(cold+'original/donor.stdout'),continuation,build)
        cold_csv=csv(read(cold+'original/result_output.csv'))
        require(len(cold_csv)==high-low+2 and cold_csv[-(high-low):]==warm_csv[low+2:high+2],'Actual original cold compatibility CSV differs')
        require(checkpoint(read(cold+f'accepted-column-1-day-{high}.zip'),build,continuation[-1],dz)==native[high],'Actual original complete cold native bytes differ')
    report.update(actual_complete_native_checkpoints=len(cuts),actual_exact_cold_windows=[list(pair) for pair in windows],domain=DOMAINS[case],actual_supply_cm=sum(r['surfacewater']['supply_cm'] for r in data),actual_discharge_cm=sum(r['surfacewater']['discharge_cm'] for r in data),actual_rejected_trials=sum(r['surfacewater']['rejected_steps'] for r in data))
    return report,build,data

def archive(path,record):
    raw=path.read_bytes();require(len(raw)==record['bytes'] and digest(raw)==record['sha256'],'Actual raw archive changed')
    z=zipfile.ZipFile(path)
    require(len(z.namelist())==len(set(z.namelist())) and set(z.namelist())==set(record['members']),'Actual archive member inventory changed')
    for name,expected in record['members'].items():
        body=z.read(name);require(len(body)==expected['bytes'] and digest(body)==expected['sha256'],'Actual raw member changed: '+name)
    return z

def capsule(path):
    record=json.loads(path.with_suffix('.json').read_text(encoding='utf8'))
    with archive(path,record) as z:
        cap=json.loads(z.read('source/RESULT.json'));raw=z.read('source/'+cap['archive'])
        require(len(raw)==cap['bytes'] and digest(raw)==cap['sha256'],'Actual producer source ZIP changed')
        with zipfile.ZipFile(io.BytesIO(raw)) as source:
            present={name for name,value in cap['members'].items() if value.get('checkout')!='ABSENT'}
            require(set(source.namelist())==present,'Actual producer source inventory changed')
            for name in present:
                body=source.read(name);value=cap['members'][name]
                require(len(body)==value['bytes'] and digest(body)==value['sha256'],'Actual producer source bytes changed')
        candidates=[name for name in ('provider/PREPARED.json','provider-PREPARED.json') if name in z.namelist()]
        require(len(candidates)==1,'Actual original provider identity missing/ambiguous')
        provider=json.loads(z.read(candidates[0]))
        require(provider['status']=='SOURCE_PROVIDER_READY_NO_MODEL_EXECUTED' and provider['original_model_executions']==provider['active_macro_executions']==0,'Original provider role changed')
        return cap,provider

def source_binding(build,cap,provider):
    identity=build['identity']
    for key,path in [('host','app/hybrid_water/daily_host.py'),('adapter','app/hybrid_water/donor_adapter.f90'),('driver','app/hybrid_water/main.f90'),('experimental_input_adapter','app/hybrid_water/experimental_project.py'),('budget_source','app/hybrid_water/hybrid_step_budget.f90')]:
        require(identity[key]==cap['members'][path]['sha256'],'Actual compiled source binding differs: '+path)
    for path,value in identity['kernel_sources']:require(cap['members'][path]['sha256']==value,'Actual compiled kernel source changed')
    extended=identity['extended_drainage']
    for key,name in [('source_sha256','extended_drainage.py'),('template_sha256','extended_drainage_state.f90'),('terminal_renderer_sha256','weather_terminal_receipt.py'),('terminal_template_sha256','terminal_water_receipt.f90'),('strict_retry_source_sha256','implicit_conductivity_retry.py'),('pond_tangent_provider_sha256','hybrid_step_budget.f90'),('pond_conservation_renderer_sha256','original_pond_budget.py'),('extended_pond_numerics_sha256','extended_pond.py'),('extended_trial_receipt_sha256','extended_trial_receipt.py'),('positive_interception_renderer_sha256','extended_interception.py')]:
        require(extended[key]==cap['members']['app/hybrid_water/'+name]['sha256'],'Actual selected original numerical/native provider changed: '+name)
    require(extended['strict_trial_water_guard_cm']==1e-10 and extended['strict_retry_clock_floor_ulps']==8 and extended['physical_equations_changed'] is False,'Actual original numerical policy changed')
    require(build['binding']['swap_source']==provider['source_archives']['SWAP.ZIP']=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151' and build['binding']['ttutil_source']==provider['source_archives']['TTUTIL.ZIP'],'Actual original source archive identity differs')
    for name,value in identity['donor_objects'].items():require(provider['provider_files']['build/swap-obj/'+name]==value,'Actual original object provider changed')
    require(identity['ttutil_library']==provider['provider_files']['build/ttutil-obj/libttutil.a'],'Actual original TTUTIL provider changed')

def component_sources(proof):
    """Read actual reference failures/corrections, never trusting PASS labels."""
    norm=lambda body:body.replace(b'\r\n',b'\n')
    raw=(proof.parents[2]/'reference/swap-4.3.1/source-archives/SWAP.ZIP').read_bytes()
    require(digest(raw)=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151','Original process ZIP authority changed')
    with zipfile.ZipFile(io.BytesIO(raw)) as original:
        reference={name:norm(original.read('SWAP/'+name)) for name in ('boundtop.f90','surfacewater.f90','MOD_meteo.f90')}
    sources={}
    def opened(name):
        path=proof/(name+'.zip');return archive(path,json.loads(path.with_suffix('.json').read_text(encoding='utf8')))
    with opened('EXTENDED_DRAINAGE_POND_COMPONENT_RAW') as z:
        for opt in ('O0','O2'):
            prefix='pond-complete/'+opt+'/'
            for mode in ('original','corrected'):
                q=json.loads(z.read(prefix+mode+'.json'))
                require(digest(z.read(prefix+mode+'-probe.exe'))==q['executable_sha256'],'Actual original pond component executable changed')
                require(digest(z.read(prefix+mode+'-boundtop.f90'))==q['rendered_source_sha256'],'Actual original pond component source changed')
                require([x['scenario'] for x in q['observations']]==['tiny-outflow','inundation','nonlinear-outflow','elevated-outflow'],'Original pond component case omitted')
                for item in q['observations']:
                    require(item['returncode']==0 and not item['stderr'],'Original pond component did not actually execute')
                    values=list(map(float,item['stdout'].split()[2:]));require(len(values)==6,'Malformed original pond observation')
                    require(abs(values[4])>1e-10 if mode=='original' else abs(values[4])<=1e-10,'Original pond reference defect/correction not witnessed')
                source=norm(z.read(prefix+mode+'-boundtop.f90')).replace(b', h0max, k1max',b'',1)
                if mode=='original':require(source==reference['boundtop.f90'],'Original pond process body changed in reference')
                elif 'boundtop.f90' in sources:require(sources['boundtop.f90']==source,'Qualified O0/O2 pond source differs')
                else:sources['boundtop.f90']=source
            q=json.loads(z.read(prefix+'tangent.json'));require(q['returncode']==0 and digest(z.read(prefix+'tangent.exe'))==q['executable_sha256'],'Actual pond derivative probe omitted')
            rows=[line.split() for line in q['stdout'].splitlines() if line.startswith('ACTUAL_POND_TANGENT ')]
            require(len(rows)==5 and [int(row[1]) for row in rows]==list(range(1,6)),'Actual piecewise original derivative branch omitted')
            for row in rows:
                a,b,error=map(float,row[2:]);require(abs(a-b)<=1e-8 and error==b-a,'Actual original routine derivative perturbation differs')
    with opened('EXTENDED_DRAINAGE_INTERCEPTION_COMPONENT_RAW') as z:
        for opt in ('O0','O2'):
            observed_rows={}
            for mode in ('original','corrected'):
                q=json.loads(z.read(opt+'/'+mode+'.json'))
                require(q['returncode']==0 and not q['stderr'] and digest(z.read(opt+'/'+mode+'-probe.exe'))==q['executable_sha256'],'Actual original interception component executable changed')
                require(digest(z.read(opt+'/'+mode+'-MOD_meteo.f90'))==q['source_sha256'],'Actual original interception component source changed')
                rows=[line.split() for line in q['stdout'].splitlines() if line.startswith('ACTUAL_ORIGINAL_INTERCEPTION ')]
                require(len(rows)==3 and [int(row[1]) for row in rows]==[1,2,3],'Actual original rain/irrigation or nonselected interception probe omitted')
                for index,row in enumerate(rows):
                    residual=float(row[-1]);require(abs(residual)>1e-10 if mode=='original' or index==2 else abs(residual)<=1e-10,'Original small-interception defect/correction not witnessed')
                observed_rows[mode]=rows
                source=norm(z.read(opt+'/'+mode+'-MOD_meteo.f90')).replace(b'public :: meteo, eintc\n',b'public :: meteo\n',1)
                if mode=='original':require(source==reference['MOD_meteo.f90'],'Original meteorology process body changed in reference')
                elif 'MOD_meteo.f90' in sources:require(sources['MOD_meteo.f90']==source,'Qualified O0/O2 interception source differs')
                else:sources['MOD_meteo.f90']=source
            require(observed_rows['original'][2]==observed_rows['corrected'][2],'Nonselected original interception response changed')
    with opened('EXTENDED_DRAINAGE_DRY_COMPONENT_RAW') as z:
        require(norm(z.read('original/surfacewater.f90'))==reference['surfacewater.f90'],'Original surfacewater reference body changed')
        sources['surfacewater.f90']=norm(z.read('corrected/surfacewater.f90'))
        old=b'            if (swstmax < 1.0d-7) then';new=b'            if (swstmax <= 0.0d0) then'
        require(sources['surfacewater.f90'].count(new)==1 and sources['surfacewater.f90'].replace(new,old,1)==reference['surfacewater.f90'],'Original surfacewater changed beyond its qualified positive-storage predicate')
        for opt in ('O0','O2'):
            for mode in ('ORIGINAL','CORRECTED'):
                q=json.loads(z.read(mode+'/'+opt+'/result.json'));require(q['returncode']==0 and not q['stderr'],'Original positive-storage test did not execute')
                values=list(map(float,q['stdout'].splitlines()[-1].split()[1:]));require(len(values)==4 and values[0]==5e-8 and values[1]==0,'Actual original positive storage/zero-flow case changed')
                require((values[2]==0 and values[3]==-5e-8) if mode=='ORIGINAL' else (values[2]==5e-8 and values[3]==0),'Original positive-storage defect/correction not witnessed')
    return sources

def physical_providers(z,prefix,sources):
    norm=lambda body:body.replace(b'\r\n',b'\n')
    for name in ('boundtop.f90','MOD_meteo.f90'):
        require(norm(z.read(prefix+name))==sources[name],'Actual compiled physical provider differs from independently qualified original component: '+name)
    text=norm(z.read(prefix+'surfacewater.f90'))
    for inserted,count in [(b'      use hybrid_extended_drainage_state,only:extended_drain_surface_flux\n',1),(b'            real(8)              :: extended_supply\n',1),(b'            extended_supply=0d0\n',1),(b'              extended_supply=wsmax\n',2),(b'                extended_supply=(swsttara-swstmax)/dt\n',1),(b'            call extended_drain_surface_flux(extended_supply,wdis)\n\n',1)]:
        require(text.count(inserted)==count,'Original surfacewater observer projection changed');text=text.replace(inserted,b'')
    require(text==sources['surfacewater.f90'],'Actual original surfacewater body changed beyond qualified dry predicate and read-only observers')

def controls(z,prefix,case_prefix,build,data,coupling_source_sha256):
    read=lambda name:z.read(prefix+name)
    q=json.loads(read('RESULT.json'));domain=build['identity']['extended_drainage']['domain'];n,r=domain[1:3];nv=11+3*r+r*n
    expected={*('domain-'+str(i) for i in range(8)),'domain-copy','clock','clock-both','negative-counter','counter-copy','counter-receipt',*('nonfinite-'+str(i) for i in (0,2,4,nv-1)),'negative-2','negative-4','value-copy','stock-receipt','trailer','old-codec','truncated','trailing'}
    require(len(q['public_refusals'])==26 and {x['label'] for x in q['public_refusals']}==expected,'Actual public refusal denominator changed')
    require(len(q['native_refusals'])==24 and {x['label'] for x in q['native_refusals']}==expected-{'counter-receipt','stock-receipt'},'Actual compiled refusal denominator changed')
    source=z.read(case_prefix+'trajectory/accepted-column-1-day-4.zip');original,parts=package(source);dz=geometry(z.read(case_prefix+'input/swap.swp').decode('cp1252'))
    require(original['binding']==build['binding'] and original['receipt']==data[3],'Actual control origin differs')
    require(q['positive_native']['returncode']==100 and 'HYBRID_READY ' in read('native-positive/column/actual.stdout').decode('utf8'),'Actual positive compiled control absent')
    names=set(z.namelist())
    for item in q['public_refusals']:
        label=item['label'];require(item['before_physical_worker'] is True and item['no_publication'] is True,'Actual public refusal published or started worker')
        require(not any(name.startswith(prefix+label+'/public/') and (name.endswith('/donor.stdout') or '/accepted-' in name) for name in names),'Actual invalid native reached public worker/namespace')
        bad=read(label+'/deliberately-forged.zip');meta,forged=package(bad)
        require(meta['binding']==original['binding'] and meta['receipt']==original['receipt'] and forged['result.end']==parts['result.end'] and forged['macro.bin']!=parts['macro.bin'],'Actual rehashed mutation changed its declared context')
        try:checkpoint(bad,build,data[3],dz)
        except ValueError:pass
        else:raise ValueError('Independent decoder accepted actual forged '+label)
        if label not in {'counter-receipt','stock-receipt'}:
            require(read(label+'/native/column/macro-origin.bin')==forged['macro.bin'],'Actual compiled loader used another mutant')
            require('HYBRID_DAY_RETURN ' not in read(label+'/native/column/actual.stdout').decode('utf8') and 'ERROR STOP' in read(label+'/native/column/actual.stderr').decode('utf8'),'Actual compiled loader did not refuse mutant')
    for item in q['native_refusals']:require(item['returncode']!=100 and item['no_day_return'] is True,'Actual compiled refusal result differs')
    require(q['transactions']==dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True),'Actual lifecycle assertions omitted')
    trials=[]
    for path,day in [('transactions/external/trial-1/',5),('transactions/external/trial-2/',5),('transactions/recovered/trial-1/',6)]:
        raw=read(path+f'accepted-column-1-day-{day}.zip');proposal=package(raw);rows=[proposal[0]['receipt']]
        require(physical(rows)==physical(data[day-1:day]),'Actual transaction physical day differs')
        inventory(rows);observed(read(path+'original/donor.stdout'),rows,build)
        checkpoint(raw,build,rows[0],dz);trials.append(proposal)
    require(trials[0]==trials[1],'Actual discarded proposal did not replay exactly')
    published,published_parts=package(read('transactions/external/accepted-column-1-day-5.zip'))
    external=dict(version=1,source_sha256=coupling_source_sha256,coupling_id='original-output',forcing='original-project')
    require(published['binding']=={**build['binding'],'external_daily':external} and published_parts==trials[1][1],'Actual external ownership/native publication differs')
    base=(date.fromisoformat(build['project']['start_date'])-date(1900,1,1)).days+1
    coupling=dict(id='original-output',revision=1,origin_revision=0,origin_sha256=digest(source),origin_day=4,window_day1900=[base+4,base+5],forcing='original-project')
    require(published['receipt']=={**trials[1][0]['receipt'],'coupling':coupling} and prefix+'transactions/recovered/accepted-column-1-day-6.zip' not in names,'Actual accept/discard/recovery ownership differs')
    cli=lines(read('public-cli/daily.jsonl'));require(q['public_cli']['returncode']==0 and physical(cli)==physical(data[4:5]),'Actual public CLI continuation differs')
    inventory(cli);observed(read('public-cli/original/donor.stdout'),cli,build)
    raw=read('public-cli/accepted-column-1-day-5.zip');checkpoint(raw,build,cli[0],dz)
    require(package(raw)[1]==published_parts,'Actual CLI and externally accepted native payload differ')
    require(q['origin_unchanged'] is True,'Actual native origin was changed')
    return dict(actual_public_refusals=26,actual_compiled_refusals=24,actual_cli_continuations=1,actual_transaction_contexts=1)

def windows(path,optimization):
    record=json.loads(path.with_suffix('.json').read_text(encoding='utf8'));reports={}
    cap,provider=capsule(path.with_name('EXTENDED_DRAINAGE_WINDOWS_SOURCE_RAW_ARCHIVE.zip'))
    sources=component_sources(path.parent)
    with archive(path,record) as z:
        for case in DOMAINS:
            reports[case],build,data=period(z,case+'/',case,optimization)
            build_files(z,case+'-build/',build)
            require(json.loads(z.read(case+'-build/BUILD.json'))==build,'Executed and retained compiled BUILD identities differ')
            source_binding(build,cap,provider)
            physical_providers(z,case+'-build/',sources)
            if case in ('water','automatic'):
                reports[case]['controls']=controls(z,case+'-controls/',case+'/',build,data,cap['members']['app/hybrid_water/daily_coupling.py']['sha256'])
            require(build['binding']['budget_retry'] is True and build['binding']['shared_pond_transfer'] is build['binding']['refresh_macro_final'] is False,'Original physical/transaction policy changed')
            for key in ('donor_flags','kernel_flags'):
                require({'-'+optimization,'-ffp-contract=off','-march=x86-64','-mtune=generic'}<=set(build['identity'][key]),'Actual separate-operation compiler arithmetic changed')
    return reports

def ubuntu(path,optimization):
    record=json.loads(path.with_suffix('.json').read_text(encoding='utf8'));reports={}
    require(record['repacked'] is False and record['actual_artifact_bytes_preserved'] is True and record['origin_artifact']['digest']=='sha256:'+record['sha256'] and record['origin_artifact']['conclusion']=='success','Actual Ubuntu artifact was rebound/repacked or incomplete')
    cap,provider=capsule(path);sources=component_sources(path.parent)
    with archive(path,record) as z:
        for case in DOMAINS:
            reports[case],build,data=period(z,case+'/',case,optimization)
            build_files(z,case+'-build/',build);require(json.loads(z.read(case+'-build/BUILD.json'))==build,'Actual Ubuntu executable BUILD identity differs')
            source_binding(build,cap,provider);physical_providers(z,case+'-build/',sources)
            require(build['binding']['budget_retry'] is True and build['binding']['shared_pond_transfer'] is build['binding']['refresh_macro_final'] is False,'Actual Ubuntu physical/transaction policy changed')
            for key in ('donor_flags','kernel_flags'):require({'-'+optimization,'-ffp-contract=off','-march=x86-64','-mtune=generic'}<=set(build['identity'][key]),'Actual Ubuntu arithmetic profile changed')
            if case!='table':reports[case]['controls']=controls(z,case+'/controls/',case+'/',build,data,cap['members']['app/hybrid_water/daily_coupling.py']['sha256'])
    return reports

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--platform',choices=['Windows','Ubuntu'],default='Windows');p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();report=(windows if a.platform=='Windows' else ubuntu)(a.archive,a.optimization)
    status='INDEPENDENT_ACTUAL_'+a.platform.upper()+'_RAW_PERIOD_NATIVE_BUILD_AUDIT_PASS'
    with a.output.open('x',encoding='utf8') as stream:json.dump(dict(status=status,reports=report,admission=False),stream,indent=2)
    print(status,a.optimization)
