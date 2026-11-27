"""Complete current source proposal and untouched historical Git evidence."""
import argparse,json
from pathlib import Path
from closed_default_calendar_feedback import R,P,PARENT,git
from closed_default_calendar_science import source_contract


def source():
    head=git('rev-parse','HEAD').decode().strip()
    assert not git('status','--porcelain=v1','--untracked-files=all','--ignored')
    assert not git('for-each-ref','--format=%(refname)','refs/replace')
    q=source_contract(head)
    assert not git('diff',PARENT,head,'--','src','tools','reference')
    def inventory(ref):
        result={}
        for row in git('ls-tree','-r',ref,'--',P).splitlines():
            fields,path=row.split(b'\t',1);result[path.decode()]=fields.split()[2].decode()
        return result
    old=inventory(PARENT);new=inventory(head);assert old.keys()<=new.keys()
    changed={name for name,digest in old.items() if new[name]!=digest}
    assert changed<={P+'STATUS.json',P+'GAP_MATRIX.json'}
    for name in git('diff','--name-only',PARENT,head,'--','app').decode().splitlines():
        assert (R/name).read_bytes().replace(b'\r\n',b'\n')==git('show',head+':'+name)
    assert git('rev-parse','HEAD').decode().strip()==head
    return dict(status='ACTUAL_DEFAULT_CALENDAR_COMPLETE_SOURCE_INVERSES_AND_ORIGINAL_GIT_EVIDENCE_PRESERVED',
        actual_source=head,actual_canonical_parent=PARENT,source_contract=q,original_evidence_blobs=len(old)-len(changed),
        physical_equations_changed=False,new_numerical_policy=False,new_native_codec=False,new_physical_state=False,
        compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=source()
    with a.output.open('x',encoding='utf8') as out:json.dump(q,out,indent=2);out.write('\n')
    print(q['status'],flush=True)
