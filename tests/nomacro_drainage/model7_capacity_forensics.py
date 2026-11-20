"""Independent actual model7 compiler/source, ledger, terminal and cold audit."""
import argparse
from datetime import date,timedelta
from decimal import Decimal,localcontext
import hashlib
import io
import json
from pathlib import Path
import zipfile
from frost_cde_drainage_portable_forensics import binary

SHA=lambda raw:hashlib.sha256(raw).hexdigest()
BASE='1d40c5ea7aa1b2344409275603a3a603a52355fe3928ad7af24eb3bbbf379dcc'
HEAD='e8693175f3c0497d83fa9a59868250d4c0b76ca4e8a88de8d825ae5c25f6255f'
RECEIPT='dc491e5faa9c7ca8e0e1e2a573cac965cb2e7f790d1cb6ad89ab82e7b90a6540'


def audit(profile,reference,allow_refusal=False):
    q=json.loads((profile/'RESULT.json').read_text(encoding='utf-8'));failed=q['status']=='FAILED'
    assert allow_refusal if failed else q['status'].startswith('CANDIDATE_ACTUAL_MODEL7_CAPACITY_') and q['status'].endswith('_PASS_NOT_ADMITTED')
    build=Path(q['build_root']);inputs=Path(q['input_root']);meta=json.loads((build/'BUILD.json').read_text(encoding='utf-8'));identity=meta['identity']
    for name,digest in q['inventory'].items():assert SHA((inputs/name).read_bytes())==digest
    for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
    for name,digest in identity['donor_objects'].items():assert SHA((reference/'build/swap-obj'/name).read_bytes())==digest
    for role,digest in meta['executable_sha256'].items():
        files=[build/('day_'+role),build/('day_'+role+'.exe')];actual=[path for path in files if path.is_file()]
        assert len(actual)==1 and SHA(actual[0].read_bytes())==digest
    assert '-'+q['optimization'] in identity['donor_flags'] and '-'+q['optimization'] in identity['kernel_flags']
    policy=identity['model7_capacity'];assert policy['IHWCKMODEL']==7 and policy['SWKIMPL']==0 and policy['original_lf_sha256']==BASE
    source=(build/'WC_K_models_04_11.f90').read_text(encoding='cp1252')
    before='   C_MvG_2_s = (WCs-WCr)*(Omega1*C1(h)/(1.0d0-Gam01) + Omega2*C2(h)/(1.0d0-Gam02))'
    after='   C_MvG_2_s = (WCs-WCr)*(Omega1*C1(h) + Omega2*C2(h))/(1.0d0-Omega1*Gam01-Omega2*Gam02)'
    assert source.count(after)==1 and SHA(source.replace(after,before,1).encode('cp1252'))==BASE
    assert SHA(source.encode('cp1252'))==policy['corrected_lf_sha256']
    terminal=identity.get('model7_terminal_water');head=(build/'headcalc.f90').read_text(encoding='cp1252')
    if terminal:
        imported='   use hybrid_model7_terminal_water_receipt, only: model7_terminal_water_residual\n   use variables, only: tcum\n'
        guard='\n         if(tcum+dt>=1d0-1d-8)then\n            if(abs(model7_terminal_water_residual())>1d-10)flnonconv=.true.\n         end if'
        for part in (imported,guard):assert head.count(part)==1;head=head.replace(part,'',1)
        private=(build/'model7_terminal_water_receipt.f90').read_text(encoding='cp1252')
        assert SHA(private.encode('cp1252'))==terminal['provider_sha256'] and terminal['water_limit_cm']==1e-10
        line="    write(*,'(a,28(1x,es25.17e3))') 'MODEL7_TERMINAL_WATER_TERMS',terms\n"
        assert private.count(line)==1;private=private.replace(line,'',1)
        inverse=[('hybrid_model7_terminal_water_receipt','hybrid_terminal_water_receipt'),
          ('model7_terminal_water_terms','terminal_water_terms'),('model7_terminal_water_residual','terminal_water_residual'),
          ('only: swmacro, swsnow, swdra, swfrost, swhyst','only: swmacro, swsnow, swdra'),
          ('      ivolbeg,ipondbeg,issnowbeg,isicbeg,swkimpl\n','      ivolbeg,ipondbeg,issnowbeg,isicbeg\n'),
          ('swmacro/=0.or.swsnow/=0.or.swdra/=1.or.swfrost/=0.or.swhyst/=0.or.swkimpl/=0','swmacro/=0.or.swsnow/=1.or.swdra/=1'),
          ('[igrai+graidt*dt,0d0,0d0, &','[igrai+graidt*dt,isnrai+snrai*dt,igsnow+gsnow*dt, &'),
          ('ievap+reva*dt,0d0,iqdra+qdrtot*dt','ievap+reva*dt,isubl+subl*dt,iqdra+qdrtot*dt'),
          ('[ivolbeg,ipondbeg,0d0,isicbeg,0d0,0d0]','[ivolbeg,ipondbeg,issnowbeg,isicbeg,0d0,0d0]'),
          (')),pond,0d0,canopy,0d0,0d0]',')),pond,ssnow,canopy,0d0,0d0]')]
        for a,b in inverse:assert a in private;private=private.replace(a,b)
        assert SHA(private.encode('cp1252'))==RECEIPT
    assert SHA(head.encode('cp1252'))==HEAD
    rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()]
    accepted=rows[:-1] if failed else rows
    assert all(row['committed'] for row in accepted)
    if failed:assert not rows[-1]['committed'] and rows[-1]['day']==len(rows)
    maximum=Decimal(0);chemical=Decimal(0);prefix=Decimal(0);waterprefix=Decimal(0);fluxsum=[Decimal(0)]*16;chemsum=[Decimal(0)]*6
    dec=lambda value:Decimal.from_float(float(value))
    with localcontext() as context:
        context.prec=80
        for day,row in enumerate(accepted,1):
            assert row['day']==day
            initial=list(map(dec,row['stock_start_cm']));final=list(map(dec,row['stock_end_cm']));flux=list(map(dec,row['external_flux_cm']))
            residual=sum(initial)-sum(final)+sum(flux[:7])-sum(flux[7:]);maximum=max(maximum,abs(residual))
            assert abs(residual)<=Decimal('1e-10') and abs(dec(row['kernel_residual_cm']))<=Decimal('1e-10')
            fluxsum=[a+b for a,b in zip(fluxsum,flux)]
            waterprefix=max(waterprefix,abs(sum(map(dec,rows[0]['stock_start_cm']))-sum(final)+sum(fluxsum[:7])-sum(fluxsum[7:])))
            if q['kind']=='cde':
                ledger=list(map(dec,row['solute_ledger_mg_cm2']));a,b=map(dec,(row['solute_start_mg_cm2'],row['solute_end_mg_cm2']))
                residual=b-a-sum(ledger[2:5])+sum(ledger[5:8]);chemical=max(chemical,abs(residual));assert abs(residual)<=Decimal('1e-10')
                chemsum=[a+b for a,b in zip(chemsum,ledger[2:8])]
                residual=b-dec(rows[0]['solute_start_mg_cm2'])-sum(chemsum[:3])+sum(chemsum[3:]);prefix=max(prefix,abs(residual));assert abs(residual)<=Decimal('1e-10')
    if terminal:
        observed={};latest=None
        for line in (profile/'trajectory/original/donor.stdout').read_text().splitlines():
            if line.startswith('MODEL7_TERMINAL_WATER_TERMS '):latest=list(map(float,line.split()[1:]));assert len(latest)==28
            elif line.startswith('ORIGINAL_DAILY_RECEIPT '):
                day=int(line.split()[1])
                if day and latest is not None:observed[day]=latest;latest=None
        assert len(observed)==len(rows)
        for row in rows:
            flux=row['external_flux_cm'];expected=flux[:7]+[-v for v in flux[7:]]+row['stock_start_cm']+[-v for v in row['stock_end_cm']]
            assert observed[row['day']]==expected,'Terminal trial/public daily receipt terms differ'
    if failed:
        assert abs(rows[-1]['independent_residual_cm'])>1e-10 and not list((profile/'trajectory').glob('accepted-*-day-'+str(len(rows))+'.zip'))
    else:
        assert SHA((build/'BUILD.json').read_bytes())==q['trajectory']['build_sha256']
        warm=profile/'trajectory';output=binary((warm/'original/result_output.bin').read_bytes())
        for own in q['own']:
            start,end=own['start'],own['end'];cold=profile/('own-'+str(start))
            a=[json.loads(line) for line in (cold/'daily.jsonl').read_text().splitlines()]
            for left,right in zip(a,rows[start:end]):
                for field in ('stock_start_cm','stock_end_cm','external_flux_cm','pressure_head_cm','groundwater_cm','drainage_outward_cm','bottom_outward_cm'):
                    assert left[field]==right[field]
                if q['kind']=='cde':
                    for field in ('solute_start_mg_cm2','solute_end_mg_cm2','solute_ledger_mg_cm2'):assert left[field]==right[field]
            assert len(a)==end-start
            with zipfile.ZipFile(io.BytesIO((warm/f'accepted-column-1-day-{end}.zip').read_bytes())) as x,zipfile.ZipFile(io.BytesIO((cold/f'accepted-column-1-day-{end}.zip').read_bytes())) as y:
                for name in ('macro.bin','result.end'):assert x.read(name)==y.read(name)
                assert x.read('macro.bin')[:8]==(b'S5IOC001' if q['kind']=='cde' else b'S5IOW001')
            first=date.fromisoformat(meta['project']['start_date']);low,high=str(first+timedelta(days=start)),str(first+timedelta(days=end))
            expected=[row for row in output[1:] if low<=row[:19].decode().strip()<high]
            assert binary((cold/'original/result_output.bin').read_bytes())[1:]==expected
    return dict(status='RETAINED_ACTUAL_MODEL7_PUBLIC_WATER_GUARD_REFUSAL_INDEPENDENTLY_CONFIRMED' if failed else 'INDEPENDENT_MODEL7_CAPACITY_SOURCE_BUDGET_NATIVE_USER_OUTPUT_PASS',producer=q['source'],kind=q['kind'],optimization=q['optimization'],days=len(rows),accepted_days=len(accepted),water_daily_max=str(maximum),CDE_daily_max=str(chemical),CDE_every_prefix_max=str(prefix),extra_absolute_global_water_prefix=str(waterprefix),extra_global_water_prefix_is_owning_gate=False,full_capacity_source_inverse=True,complete_HeadCalc_parent_inverse=True,terminal_receipt_parent_inverse=bool(terminal),all28_terminal_public_terms_exact=bool(terminal),cold_windows=0 if failed else len(q['own']),compiler_executions=0,model_executions=0,public_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--allow-refusal',action='store_true');a=p.parse_args();assert not a.output.exists()
    result=audit(a.profile,a.reference_work,a.allow_refusal)
    a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(result['status'],result['kind'],result['optimization'],result['days'])
