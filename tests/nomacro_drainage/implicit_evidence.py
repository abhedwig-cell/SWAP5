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


