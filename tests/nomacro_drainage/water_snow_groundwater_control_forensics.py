"""Read actual compiled refusals and malformed payloads, without model execution."""
from pathlib import Path
import zipfile

from ordinary_pond_evidence import read,digest,require,rows
from water_snow_groundwater_forensics import native,scalar,geometry


def audit(root,profile,build_root=None,input_root=None):
    root=Path(root);profile=Path(profile);r=read(root/'RESULT.json');p=read(profile/'RESULT.json')
    bundle=Path(build_root or p['build_root']);inputs=Path(input_root or p['input_root']);build=read(bundle/'BUILD.json')
    require(r['status']=='ACTUAL_COMPILED_WATER_SNOW_GROUNDWATER_NATIVE_REFUSALS_PASS' and
        r['actual_BUILD_sha256']==digest(bundle/'BUILD.json') and r['accepted_model_days']==0 and
        len(r['refusals'])==r['expected_compiled_refusals']==65,'Actual compiled Snow groundwater controls incomplete')
    warm=Path(p.get('trajectory_root',profile/'trajectory'));source=warm/'accepted-column-1-day-4.zip'
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
