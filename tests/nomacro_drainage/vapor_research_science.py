"""Re-read retained Kelvin probes and failed native1/2 roles without promotion."""
from contextlib import ExitStack
from decimal import Decimal,localcontext
import io
import json
import math
import zipfile
from analytical_hydraulic_archives import Archive,SHA
from vapor_hydraulic_forensics import audit,vapor_liquid_source
from vapor_mixed_component_forensics import audit as mixed
from vapor_windows_science import mapped
from model7_unselected_science import physical


def component(folder,provider,corrected):
    q=json.loads((folder/'RESULT.json').read_text());assert q.get('vapor_sign_correction',False)==corrected and q['model_periods']==0
    assert len(q['actual_original_object_closure'])==40
    for item in q['actual_original_object_closure']:
        assert SHA((provider/'swap-obj'/item['name']).read_bytes())==item['sha256']
    assert SHA((folder/'actual-hydraulic.exe').read_bytes())==q['executable_sha256']
    assert not (folder/'model8.stderr').read_bytes()
    rows={}
    for line in (folder/'model8.stdout').read_text().splitlines():
        if not line.startswith('ACTUAL_ORIGINAL_HYDRAULIC '):continue
        fields=line.split();key=tuple(map(int,fields[1:6]));values=tuple(map(float,fields[6:]));assert len(values)==11 and key not in rows
        model,soil,j,thermal,flag=key;assert model in (8,9,10,11) and soil in (1,2) and j in range(4) and thermal in (1,2,3) and flag in (0,1)
        assert values[0]==-10.0**(5-2*j) and values[1]==20*(thermal-1) and all(map(math.isfinite,values));rows[key]=values
    assert len(rows)==192
    source=(folder/'WC_K_models_04_11.f90').read_bytes().replace(b'\r\n',b'\n')
    if corrected:source=source.replace(b'Hr        = dexp(-h/100.0d0*MgRT)',b'Hr        = dexp(h/100.0d0*MgRT)',1)
    assert SHA(source)=='1d40c5ea7aa1b2344409275603a3a603a52355fe3928ad7af24eb3bbbf379dcc'
    return rows


def mass_and_native_failure(profile,build,provider,days,codec,inputs):
    q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='FAILED' and q['error']=='AssertionError()'
    assert q['trajectory']['days']==days
    for name,digest in q['inventory'].items():assert SHA((inputs/name).read_bytes())==digest
    meta=json.loads((build/'BUILD.json').read_text());assert SHA((build/'BUILD.json').read_bytes())==q['trajectory']['build_sha256']
    for name,digest in meta['identity']['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
    for role,digest in meta['executable_sha256'].items():assert SHA((build/('day_'+role+'.exe')).read_bytes())==digest
    for name,digest in meta['identity']['donor_objects'].items():assert SHA((provider/'swap-obj'/name).read_bytes())==digest
    vapor_liquid_source((build/'WC_K_models_04_11.f90').read_text(encoding='cp1252'),meta['identity']['hydraulic_vapor'])
    rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()];assert len(rows)==days and all(row['committed'] for row in rows)
    maximum=Decimal(0)
    with localcontext() as context:
        context.prec=80
        d=lambda value:Decimal.from_float(float(value))
        for row in rows:
            initial=list(map(d,row['stock_start_cm']));final=list(map(d,row['stock_end_cm']));flow=list(map(d,row['external_flux_cm']))
            residual=sum(initial)-sum(final)+sum(flow[:7])-sum(flow[7:]);maximum=max(maximum,abs(residual))
            assert abs(residual)<=Decimal('1e-10') and abs(d(row['kernel_residual_cm']))<=Decimal('1e-10')
    cold=[json.loads(line) for line in (profile/'own-530/daily.jsonl').read_text().splitlines()];assert len(cold)==2
    fields=('stock_start_cm','stock_end_cm','external_flux_cm','pressure_head_cm','groundwater_cm','drainage_outward_cm','bottom_outward_cm')
    assert any(a[field]!=b[field] for a,b in zip(cold,rows[530:532]) for field in fields)
    with zipfile.ZipFile(io.BytesIO((profile/'trajectory/accepted-column-1-day-532.zip').read_bytes())) as warm,zipfile.ZipFile(io.BytesIO((profile/'own-530/accepted-column-1-day-532.zip').read_bytes())) as restarted:
        assert warm.read('macro.bin')[:8]==codec and warm.read('macro.bin')!=restarted.read('macro.bin')
    return dict(days=days,water_daily_max=str(maximum),actual_failed_cold_window=[530,532],role='RETAINED_WARM_MASS_PASS_COLD_NATIVE_FAILURE_NOT_ADMITTED'),rows


def read(proof):
    observations=[];single={}
    with ExitStack() as stack:
        current=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_RESEARCH_RAW_V1',stack)
        water=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack);provider=water.view('original-provider-build')
        projection=json.loads(current.get('COMPILED_PROJECTION_V1.json'))
        class Reference:
            def __truediv__(self,name):
                assert name.startswith('build/')
                return provider/name[6:]
        for opt in ('O0','O2'):
            refused=current.view('profiles/hydraulic-vapor-original-'+opt+'-v1');q=json.loads((refused/'RESULT.json').read_text())
            assert q['original_models'][0]['returncode']!=0 and q['original_models'][0]['raw_rows']==48
            assert 'SIGFPE' in (refused/'model8.stderr').read_text()
            original=component(current.view('profiles/hydraulic-vapor-original-'+opt+'-v2'),provider,False)
            corrected=component(current.view('profiles/hydraulic-vapor-sign-corrected-'+opt+'-v1'),provider,True)
            maximum=Decimal(0);changed=0
            with localcontext() as context:
                context.prec=80;d=Decimal.from_float
                for key,old in original.items():
                    new=corrected[key];model,soil,j,thermal,flag=key
                    assert all(old[i]==new[i] for i in (0,1,2,3,5,6,7,10))
                    if not flag:assert old==new;continue
                    liquid=original[(model,soil,j,thermal,0)]
                    for column,head in ((4,old[0]),(8,old[0]-old[10]),(9,old[0]+old[10])):
                        ratio=(-Decimal(2)*d(abs(head))/100*(Decimal('.018015')*Decimal('9.81')/Decimal('8.314'))/(d(old[1])+Decimal('273.15'))).exp()
                        expected=d(liquid[column])+(d(old[column])-d(liquid[column]))*ratio
                        bound=8*(d(math.ulp(new[column]))+ratio*d(math.ulp(old[column]))+(1-ratio)*d(math.ulp(liquid[column])))
                        fraction=abs(d(new[column])-expected)/bound;assert fraction<=1;maximum=max(maximum,fraction)
                    changed+=old[4]!=new[4]
            assert changed==49;single[opt]=(original,corrected)
            observations.append(dict(optimization=opt,original_calls=192,corrected_calls=192,changed_central_conductivities=changed,kelvin_80digit_max_fraction_8ULP=str(maximum),original_dry_boundary_FPE_prefix_rows=48))
            for model in (8,11):
                short=current.view(f'profiles/vapor-{model}-daily-water-short-{opt}-v1');q=json.loads((short/'RESULT.json').read_text())
                result=audit(short,Reference(),locations=dict(build=current.view(projection[q['build_root']]['archive_prefix']),inputs=mapped(current,q['input_root'])))
                assert result['days']==35 and result['cold_windows']==3
                full=current.view(f'profiles/vapor-{model}-daily-water-full-{opt}-v1');q=json.loads((full/'RESULT.json').read_text())
                observed,rows=mass_and_native_failure(full,current.view(projection[q['build_root']]['archive_prefix']),provider,1096,b'S5IOW001',mapped(current,q['input_root']))
                observations.append(dict(model=model,optimization=opt,short=result,retained_failure=observed))
                if model==8 and opt=='O0':oldprefix=rows[:532]
        assert single['O0']==single['O2']
        mixed_result=mixed(current.view('profiles'))
        native2=current.view('profiles/vapor-native2-8-water-prefix-O0-v1');q=json.loads((native2/'RESULT.json').read_text())
        native2_result,rows=mass_and_native_failure(native2,current.view(projection[q['build_root']]['archive_prefix']),provider,532,b'S5HVW002',mapped(current,q['input_root']))
        assert physical(rows)==physical(oldprefix)
    return dict(status='ORIGINAL_VAPOR_KELVIN_COMPONENT_REFERENCE_AND_NATIVE1_NATIVE2_FAILURES_INDEPENDENTLY_RETAINED_NOT_ADMITTED',
        observations=observations,mixed=mixed_result,native2=native2_result,old_failures_promoted=False,compiler_executions=0,model_executions=0,public_admission=False)
