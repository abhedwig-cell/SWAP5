"""Independent actual alternating-layer derivative and state-independence audit."""
import argparse
import hashlib
import json
import math
from pathlib import Path

SHA=lambda raw:hashlib.sha256(raw).hexdigest()
PAIRS=((1,7),(7,1),(3,7),(7,3),(6,7),(7,6),(10,7),(7,10))
VISITS=(1,2,1,2,2,1)


def audit(original,corrected):
    observations={};data={}
    for name,folder in (('original',original),('corrected',corrected)):
        q=json.loads((folder/'RESULT.json').read_text());assert q['status']=='ACTUAL_ORIGINAL_HYDRAULIC_INTERFACES_OBSERVED_NO_ADMISSION' and q['mixed_original_layers']
        assert q['model7_capacity_correction']==(name=='corrected') and q['original_models']==[dict(model=7,returncode=0,raw_rows=192,status='COMPONENT_OBSERVED',stderr='')]
        for filename,item in q['original_rebuilt_sources'].items():assert SHA((folder/filename).read_bytes())==item['actual_sha256']
        assert SHA((folder/'hydraulic_mixed_analytical_probe.f90').read_bytes())==q['driver_sha256']
        exe=[p for p in (folder/'actual-hydraulic',folder/'actual-hydraulic.exe') if p.is_file()];assert len(exe)==1 and SHA(exe[0].read_bytes())==q['executable_sha256']
        assert not (folder/'model7.stderr').read_bytes() and all(c['returncode']==0 for c in q['compiler'])
        expected={(pair,models[soil-1],soil,j,visit) for pair,models in enumerate(PAIRS,1) for j in range(4) for visit,soil in enumerate(VISITS,1)}
        rows={};repeated={};errors=[];failures=[]
        for line in (folder/'model7.stdout').read_text().splitlines():
            if not line.startswith('ACTUAL_ORIGINAL_HYDRAULIC '):continue
            words=line.split();assert len(words)==16;key=tuple(map(int,words[1:6]));values=list(map(float,words[6:]));assert key not in rows and all(map(math.isfinite,values));rows[key]=values
            state=key[:4];assert state not in repeated or repeated[state]==values;repeated[state]=values
            fd=(values[6]-values[5])/(2*values[9]);error=abs(values[2]-fd)/max(abs(values[2]),abs(fd),1e-12);errors.append(error)
            if error>2e-6:failures.append(key)
        assert set(rows)==expected and len(rows)==192 and len(repeated)==64
        assert len(failures)==(96 if name=='original' else 0) and all(key[1]==7 for key in failures)
        observations[name]=dict(calls=192,distinct_states=64,capacity_mismatches=len(failures),max_scaled_capacity_error=max(errors),actual_original_object_count=len(q['actual_original_object_closure']),optimization=q['optimization'])
        data[name]=rows
    assert observations['original']['optimization']==observations['corrected']['optimization']
    for key,a in data['original'].items():
        b=data['corrected'][key]
        for index in (0,1,3,5,6,7,8,9):assert a[index]==b[index]
        if key[1]!=7:assert a==b
    before=(original/'WC_K_models_04_11.f90').read_bytes().replace(b'\r\n',b'\n');after=(corrected/'WC_K_models_04_11.f90').read_bytes().replace(b'\r\n',b'\n')
    assert SHA(before)=='1d40c5ea7aa1b2344409275603a3a603a52355fe3928ad7af24eb3bbbf379dcc' and SHA(after)=='7910cd29c045037778bfffdc7e40a77802d70fb477e0afa78be426776bd26e27'
    assert (original/'MOD_MvG_functions.f90').read_bytes()==(corrected/'MOD_MvG_functions.f90').read_bytes()
    return dict(status='ACTUAL_ORIGINAL_ALTERNATING_MIXED_LAYER_DERIVATIVE_STATE_INDEPENDENCE_PASS_NO_ADMISSION',observations=observations,
        full_capacity_source_inverse=True,water_and_conductivity_exact=True,other_model_entries_exact=True,repeated_visit_order_independent=True,
        diagnostic_scaled_FD_bound=2e-6,model_executions=0,public_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('original','corrected','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();assert not a.output.exists();result=audit(a.original,a.corrected);a.output.write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
