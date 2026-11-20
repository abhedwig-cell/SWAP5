"""Read actual original/search matrices independently; no model admission."""
import argparse
import hashlib
import itertools
import json
import math
from pathlib import Path


def inspect(folder):
    q=json.loads((folder/'RESULT.json').read_text())
    assert q['status']=='ACTUAL_ORIGINAL_SATURATED_JACOBIAN_TRIDAG_SEARCH_COMPONENT_OBSERVED_NO_ADMISSION'
    data={}
    for variant in ('original','search_diagonal'):
        raw=q['variants'][variant]
        assert raw['returncode']==0 and not raw['stderr']
        assert hashlib.sha256((folder/(variant+'.f90')).read_bytes()).hexdigest()==raw['source_sha256']
        executables=[path for path in (folder/variant,folder/(variant+'.exe')) if path.is_file()]
        assert len(executables)==1 and hashlib.sha256(executables[0].read_bytes()).hexdigest()==raw['executable_sha256']
        rows={}
        for line in raw['stdout'].splitlines():
            if not line.startswith('ACTUAL_SATURATED_JACOBIAN '):continue
            words=line.split();assert len(words)==27
            key=tuple(map(int,words[1:4]));assert key not in rows
            values=list(map(float,words[5:]));assert all(map(math.isfinite,values))
            rows[key]=(int(words[4]),values)
        assert set(rows)==set(itertools.product([1,*range(3,12)],range(3),range(1,4)))
        data[variant]=rows
    changed=0
    for key,(code,values) in data['original'].items():
        model,mode,step=key;new_code,new=data['search_diagonal'][key]
        assert values[:10]==new[:10]  # actual dt, capacity, pressure, water
        if model!=1 and mode==0:
            changed+=1;assert code==1003 and new_code==0
            assert values[1:4]==[0.,0.,0.]
            matrix=values[10:19]
            assert all(sum(matrix[row+3*column] for column in range(3))==0 for row in range(3))
            control=data['original'][(1,mode,step)][1]
            assert new[10:]==control[10:]  # actual full matrix AND original Tridag solution
            for index in range(9):
                if index not in (0,4,8):assert matrix[index]==new[10+index]
        else:
            assert code==new_code==0 and values==new
        # Independently check the solved search linear system against actual RHS.
        matrix=new[10:19];solution=new[19:22]
        for row,rhs in enumerate((.001,.002,.003)):
            residual=sum(matrix[row+3*col]*solution[col] for col in range(3))-rhs
            assert abs(residual)<1e-10
    assert changed==27
    return dict(optimization=q['optimization'],cases_per_variant=90,original_zero_pivots=changed,
        unchanged_other_cases=63,physical_values_exact=True,search_matrix_and_solution_exact_original_default_control=True,
        original_object_count=len(q['actual_original_object_closure']),result_sha256=hashlib.sha256((folder/'RESULT.json').read_bytes()).hexdigest())


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('folders',nargs=2,type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args()
    results=[inspect(folder) for folder in a.folders];assert {r['optimization'] for r in results}=={'O0','O2'}
    result=dict(status='ACTUAL_SATURATED_ORIGINAL_NULL_MODE_AND_SEARCH_OPERATOR_CONFIRMED_NO_ADMISSION',results=results,
        whole_model_qualified=False,day365_fixed=False,physical_capacity_changed=False,
        limitation='Dyadic verification geometry, prescribed interface conductances; independent of an integrated model period.')
    a.output.write_text(json.dumps(result,indent=2)+'\n');print(result['status'])


if __name__=='__main__':main()
