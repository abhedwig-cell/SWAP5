"""Independent receipts, original RIA, native and output audit; no model replay."""
import argparse
from decimal import Decimal, localcontext
import io,json,subprocess,sys,zipfile
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'tests/nomacro_scheduled_subsurface')]
from ria12_corrected_science import original_samples,standard_cde_daily,SHA
from ria12_corrected_native import native
from implicit_conductivity_forensics import water,sequential_records
from ordinary_pond_evidence import physical
from original_output_files import compare

def audit(profile,samples):
    raw=(profile/'RESULT.json').read_bytes();q=json.loads(raw)
    assert q['status']=='ACTUAL_RIA_ADDITIONAL_WATER_POLISH35_GLOBAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED'
    assert q['days']==35 and q['source']==q['actual_completion_head']
    assert not subprocess.check_output(['git','diff',q['actual_compiler_source'],q['source'],'--','app','src','tools','reference'],cwd=R)
    bundle=Path(q['build_root']);inputs=Path(q['input_root']);meta=json.loads((bundle/'BUILD.json').read_text())
    assert SHA((bundle/'BUILD.json').read_bytes())==q['actual_BUILD_sha256']
    assert dict(q['input_inventory'])==meta['inputs']=={name:SHA((inputs/name).read_bytes()) for name,_ in q['input_inventory']}
    assert meta['identity']['water_polish_policy']=='ria12-strict-water-1e-12-polish-v1'
    assert meta['identity']['time_step_policy']=='configured-dtmax-physical-growth-v2'
    for name,digest in meta['identity']['donor_generated'].items():assert SHA((bundle/name).read_bytes())==digest
    for role in ('donor','kernel'):
        paths=[bundle/('day_'+role+suffix) for suffix in ('','.exe') if (bundle/('day_'+role+suffix)).is_file()]
        assert len(paths)==1 and SHA(paths[0].read_bytes())==meta['executable_sha256'][role]
    sample=json.loads((samples/'RESULT.json').read_text());component=Path(sample['component_root'])
    assert sample['profile_RESULT_sha256']==SHA(raw) and sample['model_periods']==0
    assert sample['daily_sha256']==SHA((profile/'trajectory/daily.jsonl').read_bytes())
    assert sample['actual_soil_input_sha256']==meta['inputs']['swap.swp']
    assert json.loads((component/'COMPONENT.json').read_text())==sample['component']
    assert SHA((component/sample['component']['executable']).read_bytes())==sample['component']['executable_sha256']
    assert SHA((samples/'sample.stdout').read_bytes())==sample['stdout_sha256'] and not (samples/'sample.stderr').read_bytes()
    parameters=(samples/'original-parameters.bin').read_bytes();assert SHA(parameters)==sample['original_parameter_bytes_sha256']
    rows=lambda root:[json.loads(line) for line in (root/'daily.jsonl').read_text().splitlines()]
    warm=profile/'trajectory';data=rows(warm)
    assert len(data)==35 and [row['day'] for row in data]==list(range(1,36))
    original_samples(samples,component,sample,inputs,data)
    with localcontext() as context:
        context.prec=60;residuals=[]
        for row in data:
            dec=lambda value:Decimal(str(value))
            value=sum(map(dec,row['stock_start_cm']))+sum(map(dec,row['external_flux_cm'][:7]))-sum(map(dec,row['external_flux_cm'][7:]))-sum(map(dec,row['stock_end_cm']))
            assert abs(value)<=Decimal('1e-10');residuals.append(value)
        assert abs(sum(residuals))<=Decimal('1e-10')
        decimal_global=str(sum(residuals));decimal_peak=str(max(map(abs,residuals)))
    def receipt(root,observed):
        proof=water(observed);byday={row['day']:row for row in observed};seen=[]
        for path in root.glob('accepted-column-1-day-*.zip'):
            day=int(path.stem.rsplit('-',1)[1]);seen.append(day)
            with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
                assert set(z.namelist())=={'checkpoint.json','macro.bin','result.end'}
                checkpoint=json.loads(z.read('checkpoint.json'))
                assert checkpoint['binding']==meta['binding'] and checkpoint['receipt']==byday[day]
                assert all(SHA(z.read(name))==digest for name,digest in checkpoint['files'].items())
                native(z.read('macro.bin'),byday[day],meta,parameters);sequential_records(z.read('result.end'))
        chemical=None
        if q['kind']=='cde':
            from groundwater_snow_forensics import clock
            chemical=dict(ledger=clock.ledger(observed,len(observed)),daily=standard_cde_daily(root,observed,meta['project']['start_date']))
        return dict(water=proof,chemical=chemical,native_days=sorted(seen))
    proof=receipt(warm,data);assert proof['native_days']==[2,4,19,23,30,34,35]
    windows=[(2,4),(19,23),(30,34)];assert [(c['start'],c['end']) for c in q['cold']]==windows
    cold=[]
    for low,high in windows:
        root=profile/('own-'+str(low));observed=rows(root);assert physical(observed)==physical(data[low:high])
        result=receipt(root,observed);assert result['native_days']==[high]
        with zipfile.ZipFile(warm/f'accepted-column-1-day-{high}.zip') as left,zipfile.ZipFile(root/f'accepted-column-1-day-{high}.zip') as right:
            assert all(left.read(name)==right.read(name) for name in ('macro.bin','result.end'))
        result['original_user_output']=compare(warm/'original',root/'original',meta['identity']['original_output'],low,high,meta['project']['start_date']);cold.append(result)
    if q['kind']=='cde':assert any(row['solute_ledger_mg_cm2'][3]>0 for row in data)
    return dict(status='INDEPENDENT_RIA_WATER_POLISH_FULL35_ORIGINAL_GLOBAL_LEDGER_NATIVE_COLD_OUTPUT_PASS_NOT_ADMITTED',actual_model_source=q['source'],actual_compiler_source=q['actual_compiler_source'],actual_observer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),profile_RESULT_sha256=SHA(raw),kind=q['kind'],optimization=q['optimization'],warm=proof,cold=cold,decimal_global_water_residual_cm=decimal_global,decimal_maximum_daily_water_residual_cm=decimal_peak,absolute_water_limit_cm='1e-10',model_executions=0,compiler_executions=0,canonical_admission=False)

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for name in ('profile','reference-samples','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();q=audit(a.profile,a.reference_samples)
    with a.output.open('x') as stream:json.dump(q,stream,indent=2)
    print(q['status'],q['kind'],q['optimization'],q['decimal_global_water_residual_cm'])
