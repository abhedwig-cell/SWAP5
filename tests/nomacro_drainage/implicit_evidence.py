"""Independent actual implicit archive audit; no production imports or model executions."""
from datetime import date
import json
from pathlib import Path
import zipfile
import implicit_forensics as science
import extended_evidence as prior
from extended_forensics import require
from calendar_evidence import extracted,capsule,differences
from calendar_publisher import publisher_equivalence

def controls(root,profile,build,data,cap,positive=False,compiled_prefix=None,control_name=None):
    base=root/profile;control=base/(control_name or ('positive-controls' if positive else 'controls-v2' if (base/'controls-v2').is_dir() else 'controls'))
    q=json.loads((control/'RESULT.json').read_text());require(q['status']==('ACTUAL_EXTENDED_POSITIVE_NATIVE_CLI_TRANSACTION_PRESERVATION_PASS' if positive else 'ACTUAL_EXTENDED_NATIVE_PUBLIC_TRANSACTION_CONTROLS_PASS'),'Incomplete actual history controls');origin=base/'trajectory/accepted-column-1-day-4.zip'
    original,parts=prior.package(origin.read_bytes());dz=science.geometry((base/'input/swap.swp').read_text(encoding='cp1252'))
    selected=science.selected_input(base/'input/swap.swp')
    require(q['build_sha256']==prior.digest((root/(compiled_prefix or profile+'-build')/'BUILD.json').read_bytes()),'Actual controls used another compiler bundle')
    require(original['binding']==build['binding'] and original['receipt']==data[3],'Actual control origin differs')
    inherited=control.parent/'controls'
    def location(label,native=False):
        path=control/label
        if not (path/('native/column/actual.stdout' if native else 'deliberately-forged.zip')).is_file():path=inherited/label
        return path
    if 'inherited' in q:
        for name,digest in q['inherited']['members'].items():require(prior.digest((inherited/name).read_bytes())==digest,'Inherited original failed/control observation was overwritten')
    require(q['positive_native']['returncode']==100 and 'HYBRID_READY ' in ((inherited if 'inherited' in q else control)/'native-positive/column/actual.stdout').read_text(),'Actual valid compiled origin refused')
    public={item['label'] for item in q['public_refusals']};native={item['label'] for item in q['native_refusals']}
    n,r=build['identity']['extended_drainage']['domain'][1:3];nv=11+3*r+r*n
    expected={*('domain-'+str(i) for i in range(8)),'domain-copy','clock','clock-both','negative-counter','counter-copy','counter-receipt',*('nonfinite-'+str(i) for i in (0,2,4,nv-1)),'negative-2','negative-4','value-copy','stock-receipt','trailer','old-codec','truncated','trailing'}
    expected|={*('calendar-header-'+str(i) for i in range(7)),*('calendar-'+name for name in ('negative-counter','receipt-counter','date-pointer','flag','header-copy','value-copy','nonfinite','negative-period','old-drain-codec'))}
    if selected['kind']=='cde':expected|={*('calendar-'+name for name in ('CDE-shape','CDE-value-copy','CDE-negative-initial'))}
    if selected['swhyst']:
        expected|={*('history-'+where+'-domain-'+str(index) for where in ('physical','calendar') for index in range(5)),*('history-'+where+'-copy' for where in ('physical','calendar'))}
        expected|={*('history-nonfinite-'+str(index) for index in (0,n,2*n,3*n+1,4*n+2,5*n+2,5*n+3)),*('history-negative-'+str(index) for index in (n,2*n,3*n+1,4*n+2,5*n+3)),'history-head-receipt','history-groundwater-receipt','history-stock-receipt','history-weighted-theta','history-old-calendar-codec'}
    expected|={'implicit-explicit-codec','implicit-other-history-codec'}
    if selected['swhyst']:expected.add('implicit-other-supported-history')
    require(public==(set() if positive else expected) and native==(set() if positive else expected-{'counter-receipt','stock-receipt','calendar-receipt-counter','history-head-receipt','history-groundwater-receipt'}),'Actual history negative denominator changed')
    require(len(q['public_refusals'])==len(public) and len(q['native_refusals'])==len(native),'Duplicate actual calendar refusal label')
    for item in q['public_refusals']:
        label=item['label'];path=location(label);meta,forged=prior.package((path/'deliberately-forged.zip').read_bytes())
        require(meta['binding']==original['binding'] and meta['receipt']==original['receipt'] and forged['result.end']==parts['result.end'] and forged['macro.bin']!=parts['macro.bin'],'Actual forged control changed its declared context')
        require(not list((path/'public').rglob('donor.stdout')) and not list((path/'public').rglob('accepted-*.zip')),'Invalid public control entered worker/publication')
        try:science.checkpoint(path/'deliberately-forged.zip',build,data[3],selected,dz)
        except ValueError:pass
        else:raise ValueError('Independent reader accepted actual calendar mutant '+label)
        if label in native:
            nativepath=location(label,True)/'native/column'
            require((nativepath/'macro-origin.bin').read_bytes()==forged['macro.bin'],'Actual compiled loader received another mutant')
            require('ERROR STOP' in (nativepath/'actual.stderr').read_text() and 'HYBRID_DAY_RETURN ' not in (nativepath/'actual.stdout').read_text(),'Actual compiled loader did not refuse calendar mutant')
    require(all(item['returncode']!=100 and item['no_day_return'] is True for item in q['native_refusals']),'Actual native refusal receipt differs')
    require(q['transactions']==dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True),'Actual transaction assertions omitted')
    proposals=[]
    for folder,day in [('external/trial-1',5),('external/trial-2',5),('recovered/trial-1',6)]:
        directory=control/'transactions'/folder;path=directory/f'accepted-column-1-day-{day}.zip';meta,payload=prior.package(path.read_bytes());rows=[meta['receipt']]
        require(prior.physical(rows)==prior.physical(data[day-1:day]),'Actual transaction changed physical day')
        science.inventory(rows);science.observed((directory/'original/donor.stdout').read_bytes(),rows,build)
        science.checkpoint(path,build,rows[0],selected,dz);proposals.append((meta,payload))
    require(proposals[0]==proposals[1],'Actual rejected/discarded proposal failed exact replay')
    published,payload=prior.package((control/'transactions/external/accepted-column-1-day-5.zip').read_bytes())
    external=dict(version=1,source_sha256=cap['members']['app/hybrid_water/daily_coupling.py']['sha256'],coupling_id='original-output',forcing='original-project')
    require(published['binding']=={**build['binding'],'external_daily':external} and payload==proposals[1][1],'Actual accepted ownership/native differs')
    base_day=(date.fromisoformat(build['project']['start_date'])-date(1900,1,1)).days+1
    coupling=dict(id='original-output',revision=1,origin_revision=0,origin_sha256=prior.digest(origin.read_bytes()),origin_day=4,window_day1900=[base_day+4,base_day+5],forcing='original-project')
    require(published['receipt']=={**proposals[1][0]['receipt'],'coupling':coupling} and not (control/'transactions/recovered/accepted-column-1-day-6.zip').exists(),'Actual accept/recovery publication differs')
    rows=prior.lines((control/'public-cli/daily.jsonl').read_bytes())
    require(q['public_cli']['returncode']==0 and prior.physical(rows)==prior.physical(data[4:5]),'Actual public CLI differs')
    science.inventory(rows);science.observed((control/'public-cli/original/donor.stdout').read_bytes(),rows,build)
    path=control/'public-cli/accepted-column-1-day-5.zip';science.checkpoint(path,build,rows[0],selected,dz)
    require(prior.package(path.read_bytes())[1]==payload,'Actual CLI/native accepted payload differs')
    return dict(actual_public_refusals=len(public),actual_compiled_refusals=len(native),actual_cli_contexts=1,actual_transaction_contexts=1)

def source_binding(build,cap,provider):
    identity=build['identity']
    for key,path in [('host','app/hybrid_water/daily_host.py'),('adapter','app/hybrid_water/donor_adapter.f90'),('driver','app/hybrid_water/main.f90'),('experimental_input_adapter','app/hybrid_water/experimental_project.py'),('budget_source','app/hybrid_water/hybrid_step_budget.f90')]:
        require(identity[key]==cap['members'][path]['sha256'],'Actual compiled source binding differs: '+path)
    for path,value in identity['kernel_sources']:require(cap['members'][path]['sha256']==value,'Actual compiled kernel source changed')
    require(identity['implicit_conductivity']['source_sha256']==cap['members']['app/hybrid_water/implicit_conductivity.py']['sha256'],'Actual implicit source binding differs')
    require(identity['implicit_conductivity']['SWKIMPL']==1 and identity['implicit_conductivity']['examined_ksat_interpolation'] is False,'Unqualified implicit derivative branch')
    extended=identity['extended_drainage']
    for key,name in [('source_sha256','extended_drainage.py'),('template_sha256','extended_drainage_state.f90'),('terminal_renderer_sha256','weather_terminal_receipt.py'),('terminal_template_sha256','terminal_water_receipt.f90'),('strict_retry_source_sha256','implicit_conductivity_retry.py'),('pond_tangent_provider_sha256','hybrid_step_budget.f90'),('pond_conservation_renderer_sha256','original_pond_budget.py'),('extended_pond_numerics_sha256','extended_pond.py'),('extended_trial_receipt_sha256','extended_trial_receipt.py'),('positive_interception_renderer_sha256','implicit_interception_partition.py'),('implicit_pond_renderer_sha256','extended_implicit_pond.py')]:
        require(extended[key]==cap['members']['app/hybrid_water/'+name]['sha256'],'Actual selected original numerical/native provider changed: '+name)
    if 'continuous_saturation_renderer_sha256' in extended:
        require(extended['continuous_saturation_renderer_sha256']==cap['members']['app/hybrid_water/extended_implicit_saturation.py']['sha256'] and extended['discontinuous_original_near_saturation_behavior_preserved'] is False,'Actual corrected saturation source role changed')
    require(extended['strict_trial_water_guard_cm']==1e-10 and extended['strict_retry_clock_floor_ulps']==8 and extended['physical_equations_changed'] is False,'Actual original numerical policy changed')
    require(build['binding']['swap_source']==provider['source_archives']['SWAP.ZIP']=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151' and build['binding']['ttutil_source']==provider['source_archives']['TTUTIL.ZIP'],'Actual original source archive identity differs')
    for name,value in identity['donor_objects'].items():require(provider['provider_files']['build/swap-obj/'+name]==value,'Actual original object provider changed')
    require(identity['ttutil_library']==provider['provider_files']['build/ttutil-obj/libttutil.a'],'Actual original TTUTIL provider changed')
    selected=identity['original_output'];hys=selected.get('swhyst',0)
    paths=[('source_sha256','app/hybrid_water/'+('original_output_hysteresis.py' if hys else 'original_output.py')),('calendar_owner_sha256','app/hybrid_water/age_output_calendar.py'),('clock_owner_sha256','app/hybrid_water/age_output_clock.py'),('receipt_provider_sha256','src/process/mod_original_output_receipt.f90'),('cde_output_state_sha256','app/hybrid_water/original_cde_output_state.f90'),('vector_catalog_correction_sha256','reference/swap-4.3.1/patches/NOMACRO-VECTOR-OUTPUT-01/source.py'),('binary_correction_sha256','reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01/source.py')]
    if hys:paths += [('ordinary_owner_sha256','app/hybrid_water/original_output.py'),('domain_source_sha256','app/hybrid_water/original_output_hysteresis_domain.f90')]
    for key,path in paths:
        if selected[key] is not None:require(selected[key]==cap['members'][path]['lf_normalized_sha256'],'Actual original output source binding differs: '+path)
    require(identity['extended_drainage']['output_receipt_renderer_sha256']==cap['members']['app/hybrid_water/extended_output_receipt.py']['sha256'],'Actual implicit output receipt renderer changed')
    require(identity['restart_publisher']['source_sha256']==cap['members']['app/support/restart_publish.c']['sha256'],'Actual restart publisher source changed')

def compiled(z,prefix,build,opt):
    prior.build_files(z,prefix,build)
    require(json.loads(z.read(prefix+'BUILD.json'))==build,'Executed/retained history compiler identity differs')
    require(build['identity']['extended_drainage']['codec']==('S5EHK001' if build['identity']['original_output'].get('swhyst') else 'S5EDK001'),'Actual history native codec differs')
    for key in ('donor_flags','kernel_flags'):
        require({'-'+opt,'-ffp-contract=off','-march=x86-64','-mtune=generic'}<=set(build['identity'][key]),'Actual history arithmetic flags differ')
    libraries=[prefix+name for name in ('restart_publish.dll','restart_publish.so') if prefix+name in z.namelist()]
    require(len(libraries)==1 and prior.digest(z.read(libraries[0]))==build['identity']['restart_publisher']['library_sha256'],'Actual history publisher executable differs')


def period(root,z,prefix,opt,days,compiled_prefix=None):
    compiled_prefix=compiled_prefix or prefix+'-build';directory=root/prefix
    q=json.loads((directory/'RESULT.json').read_text());build=json.loads((root/compiled_prefix/'BUILD.json').read_text())
    require(q['parameters']['days']==days and q['parameters']['optimization']==opt,'Actual history period/optimization changed')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['public_admission'] is False,'Actual history producer promoted whole scope')
    compiled(z,compiled_prefix+'/',build,opt)
    result=science.audit_root(directory,root/compiled_prefix)
    rows=prior.lines((directory/'trajectory/daily.jsonl').read_bytes());require(rows[0]['day']==1,'Actual history warm period origin censored')
    return result,build,rows



def component(root,opt,provider):
 q=json.loads((root/'RESULT.json').read_text())
 require(q['status']=='ACTUAL_ORIGINAL_IMPLICIT_EXTENDED_POND_DERIVATIVE_AND_NONMUTATION_PASS' and q['optimization']==opt and q['actual_returncode']==0,'Actual real-original tangent component incomplete')
 require(prior.digest((root/'boundtop.f90').read_bytes())==q['actual_source_sha256'] and prior.digest((root/'probe.exe').read_bytes())==q['executable_sha256'],'Actual tangent compiler/executable bytes differ')
 require(all(provider['provider_files']['build/swap-obj/'+name]==value for name,value in q['original_objects'].items()),'Actual tangent original provider changed')
 require(not (root/'actual.stderr').read_bytes() and all(v['returncode']==0 and '-'+opt in v['command'] and '-ffp-contract=off' in v['command'] for v in q['compile']),'Actual tangent compiler arithmetic/failure differs')
 rows=[line.split() for line in (root/'actual.stdout').read_text().splitlines() if line.startswith('ACTUAL_IMPLICIT_POND_TANGENT ')]
 require(len(rows)==40 and {tuple(map(int,v[1:4])) for v in rows}=={(t,b,k) for t in (1,2) for b in range(1,6) for k in range(1,5)},'Actual tangent numerical branch denominator changed')
 import math
 for row in rows:
  partial,tangent,fd,error,old=map(float,row[4:]);require(all(math.isfinite(v) for v in (partial,tangent,fd,error,old)) and abs(fd-tangent)<=1e-8 and abs(error)<=1e-8,'Actual tangent central difference fails')
  if row[3]=='1':require(tangent==old,'Actual fixed-K tangent limit differs')
 require('ACTUAL_ORIGINAL_IMPLICIT_EXTENDED_POND_CHAIN_RULE_PASS 40' in (root/'actual.stdout').read_text(),'Actual nonmutation/component completion omitted')
 return dict(actual_cases=40,derivative_probe_absolute_threshold=1e-8,mass_guards_unchanged=True)


def phase_postimage(root,full,short,aliases):
 a=aliases[full]['actual_build_prefix'];b=aliases[short]['actual_build_prefix'];now=root/a;old=root/b
 build=json.loads((now/'BUILD.json').read_text());before=json.loads((old/'BUILD.json').read_text())
 require({p.name:p.read_bytes() for p in now.glob('*.f90')}=={p.name:p.read_bytes() for p in old.glob('*.f90')},'Implicit short/full generated numerical source changed')
 require(build['inputs']==before['inputs'] and build['project']==before['project'],'Implicit short/full input changed')
 changed=differences(before['identity'],build['identity']);require(set(changed)<={'implicit_conductivity.source_sha256','restart_publisher.library_sha256'},'Implicit short/full compiler/provider changed')
 if 'restart_publisher.library_sha256' in changed:publisher_equivalence(old/'restart_publish.dll',now/'restart_publish.dll')
 data=prior.lines((root/full/'trajectory/daily.jsonl').read_bytes());shortdata=prior.lines((root/short/'trajectory/daily.jsonl').read_bytes());require(prior.physical(data[:35])==prior.physical(shortdata),'Implicit selector-only source phase changed actual physical results')
 for day in (2,4,14,17,30,35):require(prior.package((root/full/f'trajectory/accepted-column-1-day-{day}.zip').read_bytes())[1]==prior.package((root/short/f'trajectory/accepted-column-1-day-{day}.zip').read_bytes())[1],'Implicit selector-only source phase changed native bytes')
 return dict(exact_days=35,exact_native_days=[2,4,14,17,30,35],changed_source_roles=changed)


def nonselected(root,z,opt,proof,aliases):
 import history_forensics,calendar_forensics
 reports={}
 with zipfile.ZipFile(proof/f'EXTENDED_DRAINAGE_HISTORY_WINDOWS_{opt}_RAW_ARCHIVE.zip') as old:
  before_aliases=json.loads(old.read('ACTUAL_COMPILED_ALIASES.json'))['profiles']
  for case,h in [('water',0),('automatic',0),('water',1),('automatic',2)]:
   prefix=f'off-{case}-h{h}';oldprefix='off-'+case if h==0 else 'current-'+('water' if case=='water' else 'cde');bp=aliases[prefix]['actual_build_prefix'];obp=before_aliases[oldprefix]['actual_build_prefix']
   build=json.loads(z.read(bp+'/BUILD.json'));before=json.loads(old.read(obp+'/BUILD.json'));prior.build_files(z,bp+'/',build)
   expected={name[len(obp+'/'):]:old.read(name) for name in old.namelist() if name.startswith(obp+'/') and '/' not in name[len(obp+'/'):] and name.endswith('.f90')}
   require(expected=={p.name:p.read_bytes() for p in (root/bp).glob('*.f90')},'Implicit-off actual Fortran changed')
   require(build['inputs']==before['inputs'] and build['project']==before['project'],'Implicit-off actual input/project changed')
   changed=differences(before['identity'],build['identity']);require(set(changed)<={'extended_drainage.source_sha256','experimental_input_adapter','restart_publisher.library_sha256'},'Implicit-off provider/compiler changed')
   if 'restart_publisher.library_sha256' in changed:
    with __import__('tempfile').TemporaryDirectory() as temporary:
     previous=Path(temporary)/'before.dll';previous.write_bytes(old.read(obp+'/restart_publish.dll'));publisher_equivalence(previous,root/bp/'restart_publish.dll')
   rows=prior.lines(z.read(prefix+'/trajectory/daily.jsonl'));previous=prior.lines(old.read(oldprefix+'/trajectory/daily.jsonl'));require(len(rows)==(6 if h else 5) and prior.physical(rows)==prior.physical(previous),'Implicit-off actual physical prefix changed')
   for day in (2,4):require(prior.package(z.read(prefix+f'/trajectory/accepted-column-1-day-{day}.zip'))[1]==prior.package(old.read(oldprefix+f'/trajectory/accepted-column-1-day-{day}.zip'))[1],'Implicit-off actual complete native changed')
   reports[prefix]=(history_forensics if h else calendar_forensics).audit_root(root/prefix,root/bp)
 return reports


def windows(path,opt):
 with extracted(path.with_name('EXTENDED_DRAINAGE_IMPLICIT_WINDOWS_SOURCE_RAW_ARCHIVE.zip')) as (sources,_):
  cap=capsule(sources);shortcap=capsule(sources,'short-source');provider=json.loads((sources/'provider-PREPARED.json').read_text())
 reports={}
 with extracted(path) as (root,z):
  aliases=json.loads(z.read('ACTUAL_COMPILED_ALIASES.json'))['profiles']
  expected={'full-water','full-cde',*(f'short-{c}-h{h}' for c in ('water','automatic') for h in (0,1,2)),*(f'off-{c}-h{h}' for c,h in [('water',0),('automatic',0),('water',1),('automatic',2)]),'ordinary-s0-h0','ordinary-s1-h2'}
  require(set(aliases)==expected,'Actual implicit profile/build inventory differs')
  for prefix,item in aliases.items():
   q=json.loads(z.read(prefix+'/RESULT.json'));raw=z.read(item['actual_build_prefix']+'/BUILD.json');require(prior.digest(raw)==item['actual_build_sha256']==q['trajectory']['build_sha256'] and item['producer_source']==q['source'],'Actual implicit source/build phase rebound')
  for label,case,h in [('water','water',0),('cde','automatic',2)]:
   prefix='full-'+label;bp=aliases[prefix]['actual_build_prefix'];report,build,rows=period(root,z,prefix,opt,1096,bp);source_binding(build,cap,provider)
   report['controls']=controls(root,prefix,build,rows,cap,compiled_prefix=bp,control_name='controls-v1');report['short_full_postimage']=phase_postimage(root,prefix,f'short-{case}-h{h}',aliases);reports[prefix]=report
  for case in ('water','automatic'):
   for h in (0,1,2):
    prefix=f'short-{case}-h{h}';report,build,_=period(root,z,prefix,opt,35,aliases[prefix]['actual_build_prefix']);source_binding(build,shortcap,provider);reports[prefix]=report
  import implicit_zero_boundary_forensics as ordinary
  for solu,h in [(0,0),(1,2)]:
   prefix=f'ordinary-s{solu}-h{h}';bp=aliases[prefix]['actual_build_prefix'];build=json.loads(z.read(bp+'/BUILD.json'));prior.build_files(z,bp+'/',build);reports[prefix]=ordinary.audit(root/prefix,root/bp)
   require(build['identity']['implicit_conductivity']['source_sha256']==cap['members']['app/hybrid_water/implicit_conductivity.py']['sha256'],'Actual ordinary boundary implicit source changed')
  reports['explicit-off']=nonselected(root,z,opt,path.parent,aliases);reports['component']=component(root/'component',opt,provider)
 return reports


def ubuntu(path,opt):
 record=json.loads(path.with_suffix('.json').read_text());require(record['repacked'] is False and record['origin_job_conclusion']=='success','Original Ubuntu implicit artifact repacked or not terminal success')
 with extracted(path) as (root,z):
  cap=capsule(root);provider=json.loads((root/'provider-PREPARED.json').read_text());reports={}
  for label in ('water','cde'):
   report,build,rows=period(root,z,label,opt,1096);source_binding(build,cap,provider);report['controls']=controls(root,label,build,rows,cap);reports[label]=report
 return reports

def ordinary_controls(root,profile,build,rows):
 directory=root/profile/'controls-v1';q=json.loads((directory/'RESULT.json').read_text())
 require(q['status']=='IMPLICIT_CONDUCTIVITY_NUMERICAL_NATIVE_TRANSACTION_DOMAIN_PASS' and q['build_sha256']==json.loads((root/profile/'RESULT.json').read_text())['trajectory']['build_sha256'],'Actual ordinary policy controls incomplete or rebound')
 require([len(q[k]) for k in ('policy_refusals','numerical_owner_refusals','descriptor_refusals','native_refusals')]==[38,74,13,7],'Actual ordinary guard denominator changed')
 require(all(v['status']=='REFUSED_BEFORE_WORKER' for k in ('policy_refusals','numerical_owner_refusals','descriptor_refusals') for v in q[k]),'Actual ordinary policy/provider guard failure')
 for path in directory.iterdir():
  if path.is_dir() and path.name.startswith(('policy-','owner-','descriptor-')):require(not list(path.rglob('donor.stdout')) and not list(path.rglob('accepted-*.zip')),'Actual invalid ordinary policy entered worker/publication')
 require({v['attack'] for v in q['native_refusals']}=={'magic','truncated','trailing','negative-day','changed-counter','witness','nonfinite'},'Actual ordinary native attacks differ')
 import struct
 from implicit_conductivity_forensics import output_calendar
 selected=build['identity']['original_output'];chemical=selected['kind']=='cde';n=build['project']['nodes'];cookie=b'S5IHC001' if chemical else b'S5IOW001'
 for item in q['native_refusals']:
  target=directory/('native-'+item['attack']);wire=(target/'origin/macro.bin').read_bytes();require(item['status']=='REFUSED' and not list(target.glob('accepted-*.zip')),'Actual invalid ordinary native state published')
  try:
   require(wire[:8]==cookie,'Foreign ordinary native cookie');output_calendar(wire,n,rows[3],selected,build['project']['start_date'],chemical)
  except (ValueError,UnicodeError,IndexError,struct.error):pass
  else:raise ValueError('Independent calendar reader accepted actual ordinary mutant '+item['attack'])
 require(q['transactions']==dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True),'Actual ordinary transaction assertions omitted')
 proposals=[]
 for folder,day in [('external/trial-1',5),('external/trial-2',5),('recovered/trial-1',6)]:
  path=directory/'active'/folder/f'accepted-column-1-day-{day}.zip';meta,payload=prior.package(path.read_bytes());receipt={k:v for k,v in meta['receipt'].items() if k!='coupling'}
  require(prior.physical([receipt])==prior.physical(rows[day-1:day]),'Actual ordinary proposal changed physical day');proposals.append((meta,payload))
 require(proposals[0]==proposals[1],'Actual discarded ordinary proposal failed exact replay')
 meta,payload=prior.package((directory/'active/external/accepted-column-1-day-5.zip').read_bytes());require(payload==proposals[1][1] and not (directory/'active/recovered/accepted-column-1-day-6.zip').exists(),'Actual ordinary accept/discard publication differs')
 require(q['foreign_numerical_adoption']['status']=='REFUSED' and q['foreign_numerical_adoption']['origin_unchanged'] is True,'Actual foreign numerical state adopted')
 return dict(actual_policy_provider_refusals=112,actual_descriptor_refusals=13,actual_native_refusals=7,actual_transaction_contexts=1)


def precorrection_windows(path,opt):
 with extracted(path.with_name('EXTENDED_DRAINAGE_IMPLICIT_PRECORRECTION_WINDOWS_SOURCE_RAW_ARCHIVE.zip')) as (sources,_):
  cap=capsule(sources);shortcap=capsule(sources,'short-source');provider=json.loads((sources/'provider-PREPARED.json').read_text())
 reports={}
 with extracted(path) as (root,z):
  aliases=json.loads(z.read('ACTUAL_COMPILED_ALIASES.json'))['profiles'];require(len(aliases)==15,'Actual pre-correction profile denominator differs')
  for prefix,item in aliases.items():
   q=json.loads(z.read(prefix+'/RESULT.json'));raw=z.read(item['actual_build_prefix']+'/BUILD.json');require(prior.digest(raw)==item['actual_build_sha256'] and item['producer_source']==q['source'] and item['producer_status']==q['status'],'Actual pre-correction source/build phase rebound')
  bp=aliases['full-water']['actual_build_prefix'];report,build,rows=period(root,z,'full-water',opt,1096,bp);source_binding(build,cap,provider);report['controls']=controls(root,'full-water',build,rows,cap,compiled_prefix=bp,control_name='controls-v1');report['short_full_postimage']=phase_postimage(root,'full-water','short-water-h0',aliases);reports['full-water']=report
  import implicit_failure_forensics as failed
  for h in (0,2):
   prefix=f'failed-cde-h{h}';bp=aliases[prefix]['actual_build_prefix'];build=json.loads(z.read(bp+'/BUILD.json'));prior.build_files(z,bp+'/',build);source_binding(build,cap,provider);reports[prefix]=failed.audit(root/prefix,root/bp)
  for case in ('water','automatic'):
   for h in (0,1,2):
    prefix=f'short-{case}-h{h}';report,build,_=period(root,z,prefix,opt,35,aliases[prefix]['actual_build_prefix']);source_binding(build,shortcap,provider);reports[prefix]=report
  import implicit_zero_boundary_forensics as ordinary
  for solu,h in [(0,0),(1,2)]:
   prefix=f'ordinary-s{solu}-h{h}';bp=aliases[prefix]['actual_build_prefix'];build=json.loads(z.read(bp+'/BUILD.json'));prior.build_files(z,bp+'/',build);reports[prefix]=ordinary.audit(root/prefix,root/bp)
   if (root/prefix/'controls-v1').is_dir():reports[prefix]['controls']=ordinary_controls(root,prefix,build,prior.lines(z.read(prefix+'/trajectory/daily.jsonl')))
  reports['explicit-off']=nonselected(root,z,opt,path.parent,aliases);reports['pond-component']=component(root/'pond-component',opt,provider)
  import implicit_saturation_forensics as saturation
  reports['saturation-component']=saturation.audit(root/'saturation-component')
  component_q=json.loads(z.read('saturation-component/RESULT.json'));require(component_q['actual_baseline_build_sha256']==aliases['failed-cde-h0']['actual_build_sha256'] and component_q['actual_baseline_source_sha256']==prior.digest(z.read(aliases['failed-cde-h0']['actual_build_prefix']+'/MOD_MvG_functions.f90')),'Actual original/corrected constitutive probe baseline differs')
 return reports


def precorrection_ubuntu(path,opt):
 record=json.loads(path.with_suffix('.json').read_text());require(record['repacked'] is False and record['origin_job_conclusion']=='failure','Original failed Ubuntu artifact repacked or relabelled')
 with extracted(path) as (root,z):
  cap=capsule(root);provider=json.loads((root/'provider-PREPARED.json').read_text());reports={}
  report,build,rows=period(root,z,'water',opt,1096);source_binding(build,cap,provider);report['controls']=controls(root,'water',build,rows,cap);reports['water']=report
  build=json.loads(z.read('cde-build/BUILD.json'));prior.build_files(z,'cde-build/',build);source_binding(build,cap,provider)
  import implicit_failure_forensics as failed
  reports['failed-cde-h2']=failed.audit(root/'cde',root/'cde-build')
 return reports

def input_domain(directory,build,primary=False):
 import re
 text=(directory/'input/swap.dra').read_text(encoding='cp1252')
 def one(key):
  values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([+-]?\d+)[ \t]*(?:!.*)?$',text);require(len(values)==1,'Missing/ambiguous actual original drainage '+key);return int(values[0])
 levels,mode,secondary,division=map(one,('NRSRF','SWSRF','SWSEC','SWDIVD'));n=build['project']['nodes']
 require(build['identity']['extended_drainage']['domain']==[1,n,levels,mode,secondary,mode-2,levels-(mode-2),division],'Actual original drainage input/native domain differs')
 if primary:require(mode==3,'Unqualified secondary-only implicit profile promoted')


from functools import lru_cache
@lru_cache(maxsize=None)
def corrected_module(proof,opt):
 path=Path(proof)/f'EXTENDED_DRAINAGE_IMPLICIT_PRECORRECTION_WINDOWS_{opt}_RAW_ARCHIVE.zip'
 with prior.archive(path,json.loads(path.with_suffix('.json').read_text())) as z:
  return z.read('saturation-component/corrected-MOD_MvG_functions.f90').replace(b'\r\n',b'\n')


def corrected_source(proof,opt,compiled_root):
 require((compiled_root/'MOD_MvG_functions.f90').read_bytes().replace(b'\r\n',b'\n')==corrected_module(str(proof),opt),'Actual full-model constitutive source differs from independently qualified real component')


def ordinary_current(root,prefix,old,oldprefix,aliases):
 directory=root/prefix;q=json.loads((directory/'RESULT.json').read_text());bp=aliases[oldprefix]['actual_build_prefix'];build=json.loads(old.read(bp+'/BUILD.json'))
 require(q['status']=='ACTUAL_CURRENT_PUBLIC_ORDINARY_ZERO_BOUNDARY_UNCHANGED_COMPILED_NATIVE_POSTIMAGE_PASS' and q['actual_old_build_sha256']==prior.digest(old.read(bp+'/BUILD.json')) and q['returncode']==0 and q['new_compilations']==q['new_full_periods']==0,'Actual ordinary current receiver used foreign/changed compiled bundle')
 require(json.loads((directory/'public/BUILD.json').read_text())==build,'Actual ordinary current public bundle differs')
 rows=prior.lines((directory/'public/daily.jsonl').read_bytes());before=prior.lines(old.read(oldprefix+'/trajectory/daily.jsonl'));require(len(rows)==4 and prior.physical(rows)==prior.physical(before[30:34]),'Actual ordinary current public physical receipt changed')
 require(prior.package((directory/'public/accepted-column-1-day-34.zip').read_bytes())[1]==prior.package(old.read(oldprefix+'/trajectory/accepted-column-1-day-34.zip'))[1],'Actual ordinary current complete native changed')
 from implicit_conductivity_forensics import water,original_observations
 report=water(rows);original_observations((directory/'public/original/donor.stdout').read_bytes(),rows,build['project']['start_date'])
 return dict(actual_days=4,exact_complete_native_day=34,unchanged_actual_compiled_sha256=q['actual_old_build_sha256'],independent_water=report)


def corrected_windows(path,opt):
 with extracted(path.with_name('EXTENDED_DRAINAGE_IMPLICIT_CORRECTED_WINDOWS_SOURCE_RAW_ARCHIVE.zip')) as (sources,_):
  cap=capsule(sources);provider=json.loads((sources/'provider-PREPARED.json').read_text())
 reports={}
 with extracted(path) as (root,z):
  aliases=json.loads(z.read('ACTUAL_COMPILED_ALIASES.json'))['profiles'];require(len(aliases)==8,'Actual corrected numeric phase profile count changed')
  for prefix,item in aliases.items():
   q=json.loads(z.read(prefix+'/RESULT.json'));raw=z.read(item['actual_build_prefix']+'/BUILD.json');require(prior.digest(raw)==item['actual_build_sha256'] and (item['producer_source'],item['producer_status'])==(q['source'],q['status']),'Actual corrected numeric source/build phase rebound')
  with zipfile.ZipFile(path.with_name(f'EXTENDED_DRAINAGE_IMPLICIT_PRECORRECTION_WINDOWS_{opt}_RAW_ARCHIVE.zip')) as old:
   before_aliases=json.loads(old.read('ACTUAL_COMPILED_ALIASES.json'))['profiles']
   for h in (0,2):
    prefix=f'full-cde-h{h}';bp=aliases[prefix]['actual_build_prefix'];report,build,rows=period(root,z,prefix,opt,1096,bp);source_binding(build,cap,provider);input_domain(root/prefix,build,True);corrected_source(path.parent,opt,root/bp)
    report['controls']=controls(root,prefix,build,rows,cap,compiled_prefix=bp,control_name='controls-v1')
    prior_prefix=before_aliases[f'failed-cde-h{h}']['actual_build_prefix'];before=json.loads(old.read(prior_prefix+'/BUILD.json'));require(build['inputs']==before['inputs'] and build['project']==before['project'],'Corrected same-context regression changed original inputs')
    expected={name[len(prior_prefix+'/'):]:old.read(name) for name in old.namelist() if name.startswith(prior_prefix+'/') and '/' not in name[len(prior_prefix+'/'):] and name.endswith('.f90') and not name.endswith('/MOD_MvG_functions.f90')}
    require(expected=={p.name:p.read_bytes() for p in (root/bp).glob('*.f90') if p.name!='MOD_MvG_functions.f90'},'Corrected integrated nonconstitutive physical source changed')
    reports[prefix]=report
   for solu,h in [(0,0),(1,2)]:reports[f'ordinary-current-s{solu}-h{h}']=ordinary_current(root,f'ordinary-current-s{solu}-h{h}',old,f'ordinary-s{solu}-h{h}',before_aliases)
  prefix='failed-water-secondary';bp=aliases[prefix]['actual_build_prefix'];build=json.loads(z.read(bp+'/BUILD.json'));prior.build_files(z,bp+'/',build);source_binding(build,cap,provider);input_domain(root/prefix,build);corrected_source(path.parent,opt,root/bp)
  import implicit_failure_forensics as failed
  reports[prefix]=failed.audit(root/prefix,root/bp)
  prefix='primary-water-short';bp=aliases[prefix]['actual_build_prefix'];reports[prefix],build,_=period(root,z,prefix,opt,35,bp);source_binding(build,cap,provider);input_domain(root/prefix,build,True);corrected_source(path.parent,opt,root/bp)
  reports['explicit-off']=nonselected(root,z,opt,path.parent,aliases)
 return reports


def corrected_ubuntu(path,opt):
 record=json.loads(path.with_suffix('.json').read_text());require(record['repacked'] is False and record['origin_job_conclusion']=='failure','Original corrected Ubuntu artifact repacked or relabelled')
 with extracted(path) as (root,z):
  cap=capsule(root);provider=json.loads((root/'provider-PREPARED.json').read_text());reports={}
  report,build,rows=period(root,z,'cde',opt,1096);source_binding(build,cap,provider);input_domain(root/'cde',build,True);corrected_source(path.parent,opt,root/'cde-build');report['controls']=controls(root,'cde',build,rows,cap);reports['cde']=report
  build=json.loads(z.read('water-build/BUILD.json'));prior.build_files(z,'water-build/',build);source_binding(build,cap,provider);input_domain(root/'water',build);corrected_source(path.parent,opt,root/'water-build')
  import implicit_failure_forensics as failed
  reports['failed-water-secondary']=failed.audit(root/'water',root/'water-build')
 return reports

if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--precorrection',action='store_true');p.add_argument('--corrected',action='store_true')
 a=p.parse_args();call=(precorrection_windows if a.platform=='Windows' else precorrection_ubuntu) if a.precorrection else (corrected_windows if a.platform=='Windows' else corrected_ubuntu) if a.corrected else (windows if a.platform=='Windows' else ubuntu);reports=call(a.archive,a.optimization)
 with a.output.open('x') as stream:json.dump(dict(status='INDEPENDENT_ACTUAL_IMPLICIT_ARCHIVE_SOURCE_COMPILER_NATIVE_OBSERVATION_CONTROLS_PASS',reports=reports,model_executions=0,public_admission=False),stream,indent=2)
 print('INDEPENDENT_IMPLICIT_ARCHIVE_PASS',a.platform,a.optimization)
