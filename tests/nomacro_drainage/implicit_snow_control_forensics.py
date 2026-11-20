"""Read actual malformed payloads, compiled errors and forged source evidence."""
import hashlib
from pathlib import Path
import struct
import zipfile

from implicit_snow_forensics import native,scalar
from ordinary_pond_evidence import read,digest,require,rows


def native_controls(root,profile,build_root=None,input_root=None):
    root=Path(root);profile=Path(profile);r=read(root/'RESULT.json');p=read(profile/'RESULT.json')
    buildpath=Path(build_root or p['build_root']);build=read(buildpath/'BUILD.json');selected=build['identity']['original_output']
    require(r['status']=='ACTUAL_COMPILED_IMPLICIT_SNOW_ROOT_NATIVE_REFUSALS_PASS' and
        r['actual_BUILD_sha256']==digest(buildpath/'BUILD.json') and r['accepted_model_days']==0,
        'Actual compiled root refusal producer incomplete/rebound')
    source=profile/'trajectory/accepted-column-1-day-4.zip'
    require(digest(source)==r['original_checkpoint_sha256'],'Original root control checkpoint changed')
    with zipfile.ZipFile(source) as z:good=z.read('macro.bin')
    swp=(Path(input_root or p['input_root'])/'swap.swp').read_text(encoding='cp1252')
    selectors={k:scalar(swp,k) for k in ('SWKIMPL','SWSNOW','SWSOLU','SWHYST','SWBOTB','SWDRA')}
    row=rows(profile/'trajectory')[3];native(good,row,build,selected,selectors)
    expected={'parent-codec','other-water-codec','missing-tail','truncated-tail','extra-tail'}
    expected|={prefix+str(i) for prefix in ('domain-','domain-witness-') for i in range(8)}
    expected|={prefix+str(i) for prefix in ('nan-','value-witness-') for i in range(2)}
    require(len(r['refusals'])==r['expected_compiled_refusals']==25 and
        {x['attack'] for x in r['refusals']}==expected,'Actual compiled root refusal denominator differs')
    for item in r['refusals']:
        path=root/item['attack'];bad=(path/'origin/macro.bin').read_bytes()
        require(bad!=good and item['status']=='REFUSED' and item['authority']=='compiled_native',
            'Actual compiled root attack payload/authority differs')
        try:native(bad,row,build,selected,selectors)
        except (ValueError,struct.error,UnicodeError):pass
        else:raise ValueError('Independent decoder accepted actual malformed root payload')
        stderr='\n'.join(p.read_text(encoding='utf-8',errors='replace') for p in path.rglob('donor.stderr'))
        require('ERROR STOP' in stderr and stderr==item['diagnostic'] and not list(path.rglob('accepted-*.zip')),
            'Actual compiled root refusal log/publication differs')
    return dict(status='INDEPENDENT_COMPILED_ROOT_NATIVE_REFUSALS_PASS',actual_compiled_refusals=25,
        independent_actual_payload_refusals=25,actual_BUILD_sha256=r['actual_BUILD_sha256'])


def source_controls(root,build_root):
    root=Path(root);buildpath=Path(build_root);r=read(root/'RESULT.json');baseline=read(buildpath/'BUILD.json')
    require(r['status']=='ACTUAL_IMPLICIT_SNOW_PUBLIC_SOURCE_REFUSALS_PASS' and
        r['actual_BUILD_sha256']==digest(buildpath/'BUILD.json') and r['model_executions']==r['compilations']==0,
        'Actual source refusal producer incomplete/rebound')
    require(len(r['refusals'])==r['expected_refusals'] and len({v['attack'] for v in r['refusals']})==len(r['refusals']),
        'Actual source refusal denominator differs')
    for item in r['refusals']:
        label=item['attack'];forged=read(root/(label+'.BUILD.json'))
        require(item['status']=='REFUSED' and item['authority']=='public_source_preflight' and item['diagnostic'] and
            forged['inputs']==baseline['inputs'] and forged['project']==baseline['project'] and
            forged['executable_sha256']==baseline['executable_sha256'],'Actual source refusal evidence differs')
        changed=root/(label+'.mutated')
        if changed.exists():
            actual=changed.read_bytes();require(actual!=(buildpath/label).read_bytes(),'Actual forged source payload unchanged')
            if label in baseline['identity']['donor_generated']:
                require(forged['identity']['donor_generated'][label]==hashlib.sha256(actual).hexdigest(),
                    'Actual source attack omitted the claimed forged generated hash')
        else:require(forged['identity']!=baseline['identity'],'Actual forged source policy unchanged')
    return dict(status='INDEPENDENT_IMPLICIT_SNOW_PUBLIC_SOURCE_REFUSALS_PASS',actual_refusals=len(r['refusals']),
        actual_BUILD_sha256=r['actual_BUILD_sha256'],model_executions=0,compilations=0)
