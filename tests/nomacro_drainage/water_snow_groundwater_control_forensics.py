"""Read actual compiled refusals and malformed payloads, without model execution."""
from pathlib import Path
import zipfile

from ordinary_pond_evidence import read,digest,require,rows
from water_snow_groundwater_forensics import native,scalar,geometry


def source_controls(root,bundle):
    root=Path(root);bundle=Path(bundle);r=read(root/'RESULT.json');baseline=read(bundle/'BUILD.json')
    require(r['status']=='ACTUAL_WATER_SNOW_GROUNDWATER_PUBLIC_SOURCE_REFUSALS_PASS' and
        r['actual_BUILD_sha256']==digest(bundle/'BUILD.json') and r['model_executions']==r['compilations']==0 and
        len(r['refusals'])==r['expected_refusals']==16,'Actual source forgery controls incomplete')
    expected={'headcalc.f90','timecontrol.f90','integral.f90','boundtop.f90','macropore.f90',
        'snow_water_groundwater_native_state.f90','snow_water_groundwater_root_state.f90',
        'original_output_thermal_domain.f90','thermal_output_snow_calendar_state.f90',
        'hybrid_age_output_state.f90','age_output_calendar_probe.f90','implicit_pond_event_state.f90',
        'implicit_pond_availability.f90','native-codec','root-provider','trial-guard'}
    require({v['attack'] for v in r['refusals']}==expected,'Actual source forgery denominator differs')
    for item in r['refusals']:
        label=item['attack'];forged=read(root/(label+'.BUILD.json'));changed=root/(label+'.mutated')
        require(item['status']=='REFUSED' and item['authority']=='public_source_preflight' and item['diagnostic'] and
            forged['inputs']==baseline['inputs'] and forged['project']==baseline['project'] and
            forged['executable_sha256']==baseline['executable_sha256'],'Actual forged source context/authority differs')
        if changed.exists():
            raw=changed.read_bytes();require(raw!=(bundle/label).read_bytes(),'Actual source forgery unchanged')
            if label in baseline['identity']['donor_generated']:
                require(forged['identity']['donor_generated'][label]==__import__('hashlib').sha256(raw).hexdigest(),
                    'Actual forged generated source hash missing')
        else:require(forged['identity']!=baseline['identity'],'Actual forged source policy unchanged')
    return dict(status='INDEPENDENT_ACTUAL_WATER_SNOW_SOURCE_FORGERIES_PASS',actual_source_refusals=16,model_executions=0,compilations=0)


def transactions(root,profile,bundle=None,inputs=None,external_source_sha=None,trajectory_root=None):
    from datetime import date
    import hashlib
    root=Path(root);profile=Path(profile);r=read(root/'RESULT.json');p=read(profile/'RESULT.json')
    bundle=Path(bundle or p['build_root']);inputs=Path(inputs or p['input_root']);build=read(bundle/'BUILD.json')
    require(r['status']=='ACTUAL_IMPLICIT_SNOW_EXTERNAL_TRANSACTION_PASS' and
        r['actual_BUILD_sha256']==digest(bundle/'BUILD.json') and r['actual_profile_sha256']==digest(profile/'RESULT.json') and
        r['checks']==dict.fromkeys(('discard_no_day_advance','replay_exact','accept_exact','recovered_next_day_exact','origin_unchanged'),True),
        'Actual transaction binding or checks differ')
    text=(inputs/'swap.swp').read_text(encoding='cp1252');n=build['project']['nodes'];dz=geometry((inputs/'swap.swp').read_bytes(),n)
    s={k:scalar(text,k) for k in ('SWKIMPL','SWSNOW','SWSOLU','SWHYST','SWBOTB','SWDRA','SWCFBS','NPRINTDAY','SWRES')}
    warm=Path(trajectory_root or p.get('trajectory_root',profile/'trajectory'));data=rows(warm);epoch=(date.fromisoformat(build['project']['start_date'])-date(1900,1,1)).days+1
    def checkpoint(path,row,published=False):
        with zipfile.ZipFile(path) as z:
            require(set(z.namelist())=={'checkpoint.json','macro.bin','result.end'},'Actual transaction inventory differs')
            m=__import__('json').loads(z.read('checkpoint.json'));binding=dict(m['binding']);receipt=dict(m['receipt'])
            if published:
                require(binding.pop('external_daily',None)==dict(version=1,source_sha256=external_source_sha,
                    coupling_id='original-output',forcing='original-project'),'Actual external source binding differs')
                require(receipt.pop('coupling',None)==dict(id='original-output',revision=1,origin_revision=0,
                    origin_sha256=digest(warm/'accepted-column-1-day-4.zip'),origin_day=4,
                    window_day1900=[epoch+4,epoch+5],forcing='original-project'),'Actual external origin/revision differs')
            from ordinary_pond_evidence import physical
            require(binding==build['binding'] and physical([receipt])==physical([row]) and set(m['files'])=={'macro.bin','result.end'},
                'Actual transaction original receipt/binding differs')
            payload={name:z.read(name) for name in m['files']}
            require(all(hashlib.sha256(v).hexdigest()==m['files'][name] for name,v in payload.items()),'Actual transaction digest differs')
            native(payload['macro.bin'],row,build,s,dz);return payload
    actual=root/'actual';origin=checkpoint(warm/'accepted-column-1-day-4.zip',data[3])
    first=checkpoint(actual/'external/trial-1/accepted-column-1-day-5.zip',data[4])
    require(checkpoint(actual/'external/trial-2/accepted-column-1-day-5.zip',data[4])==first and
        checkpoint(actual/'external/accepted-column-1-day-5.zip',data[4],True)==first,'Actual replay/published bytes differ')
    checkpoint(actual/'recovered/trial-1/accepted-column-1-day-6.zip',data[5])
    for rel,expected in (('external/verified-initial-origin',origin),('external/trial-1/origin',origin),
        ('external/trial-2/origin',origin),('recovered/verified-initial-origin',first)):
        require(all((actual/rel/name).read_bytes()==raw for name,raw in expected.items()),'Actual transaction origin changed')
    return dict(status='INDEPENDENT_ACTUAL_WATER_SNOW_EXTERNAL_TRANSACTION_PAYLOADS_PASS',model_executions=0)


def audit(root,profile,build_root=None,input_root=None,trajectory_root=None):
    root=Path(root);profile=Path(profile);r=read(root/'RESULT.json');p=read(profile/'RESULT.json')
    bundle=Path(build_root or p['build_root']);inputs=Path(input_root or p['input_root']);build=read(bundle/'BUILD.json')
    require(r['status']=='ACTUAL_COMPILED_WATER_SNOW_GROUNDWATER_NATIVE_REFUSALS_PASS' and
        r['actual_BUILD_sha256']==digest(bundle/'BUILD.json') and r['accepted_model_days']==0 and
        len(r['refusals'])==r['expected_compiled_refusals']==65,'Actual compiled Snow groundwater controls incomplete')
    warm=Path(trajectory_root or p.get('trajectory_root',profile/'trajectory'));source=warm/'accepted-column-1-day-4.zip'
    require(digest(source)==r['original_checkpoint_sha256'],'Actual original control checkpoint changed')
    with zipfile.ZipFile(source) as z:good=z.read('macro.bin')
    text=(inputs/'swap.swp').read_text(encoding='cp1252');n=build['project']['nodes']
    selectors={k:scalar(text,k) for k in ('SWKIMPL','SWSNOW','SWSOLU','SWHYST','SWBOTB','SWDRA','SWCFBS','NPRINTDAY','SWRES')}
    dz=geometry((inputs/'swap.swp').read_bytes(),n);row=rows(warm)[3];native(good,row,build,selectors,dz)
    expected={'parent-codec','other-numerical-codec','missing-hydraulic','missing-root','truncated','trailing','hydraulic-mass'}
    expected|={prefix+str(i) for prefix in ('hydraulic-domain-','hydraulic-witness-') for i in range(13)}
    expected|={'hydraulic-nan-'+str(i) for i in (0,n,2*n,3*n+1,4*n+2,5*n+2,5*n+3)}
    expected|={'hydraulic-negative-'+str(i) for i in (n,2*n,3*n+1,4*n+2,5*n+3)}
    expected|={prefix+str(i) for prefix in ('root-domain-','root-witness-') for i in range(8)}
    expected|={prefix+str(i) for prefix in ('root-nan-','root-value-witness-') for i in range(2)}
    require({v['attack'] for v in r['refusals']}==expected and len(expected)==65,'Actual compiled attack set differs')
    positive=root/'positive-startup/original'
    require((positive/'macro-origin.bin').read_bytes()==good and not (positive/'donor.stderr').read_bytes() and
        'HYBRID_READY ' in (positive/'donor.stdout').read_text(encoding='utf-8') and
        'HYBRID_DAY_RETURN ' not in (positive/'donor.stdout').read_text(encoding='utf-8') and
        r['positive_original_startup']['returncode'] in (0,100),'Actual original positive compiled startup differs')
    for item in r['refusals']:
        path=root/item['attack'];bad=(path/'origin/macro.bin').read_bytes()
        require(bad!=good and (path/'original/macro-origin.bin').read_bytes()==bad and
            item['status']=='REFUSED' and item['authority']=='compiled_native' and item['returncode']!=0 and
            item['identical_payload_public_preflight_refused'] is True,'Actual malformed compiled payload/authority differs')
        stderr=(path/'original/donor.stderr').read_text(encoding='utf-8');stdout=(path/'original/donor.stdout').read_text(encoding='utf-8')
        require(stderr==item['diagnostic'] and 'ERROR STOP' in stderr and 'HYBRID_READY' not in stdout and
            'HYBRID_DAY_RETURN' not in stdout and not list(path.rglob('accepted-*.zip')),'Actual compiled refusal output/publication differs')
        try:native(bad,row,build,selectors,dz)
        except (ValueError,UnicodeError,__import__('struct').error):pass
        else:raise ValueError('Independent reader accepted actual malformed compiled payload')
    return dict(status='INDEPENDENT_ACTUAL_WATER_SNOW_NATIVE_COMPILED_REFUSALS_PASS',actual_compiled_refusals=65,
        actual_identical_payload_public_refusals=65,actual_positive_compiled_startups=1,accepted_model_days=0,model_executions=0)
