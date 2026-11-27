"""Exact complete workflow inverse for the two original-evidence checkout changes."""
import argparse,hashlib,json,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[2]
PATH='.github/workflows/fci-canonical.yml'
PARENT='ae54d7d621a07e54dd8f9fdb758585b2a2cc754d'
PARENT_SHA='44f14c20273706cfb91fe8a949d8e9db881d48b5e4fc9e10e764d9ed68a85cef'
CURRENT_SHA='2b64bdc8dad6c021f5dc46ce3d3ba4ea427e4005f76f912edc9b099485938863'
EXACT='            /*\n            !/integration/**/*.zip\n            !/integration/**/*.zip.part*\n'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def historical_parent(path,text):
    if path!=PATH or SHA(text.encode())!=CURRENT_SHA or text.count(EXACT)!=2:
        raise ValueError('Foreign complete closed default checkout workflow: '+path)
    before=text.replace(EXACT,'            /*\n',2)
    if SHA(before.encode())!=PARENT_SHA:
        raise ValueError('Changed complete original closed default workflow body')
    return before


def audit():
    raw=(R/PATH).read_bytes().replace(b'\r\n',b'\n');text=raw.decode()
    before=historical_parent(PATH,text)
    original=subprocess.check_output(['git','show',PARENT+':'+PATH],cwd=R)
    assert before.encode()==original
    # Exercise actual program-body, ancestry and partial-checkout mutations.
    mutants=[text.replace('python3','echo',1),text.replace('fetch-depth: 0','fetch-depth: 1',1),
             text.replace('            !/integration/**/*.zip\n','',1),
             text.replace('            !/integration/**/*.zip.part*\n','',1),
             text.replace('            /*\n','            /app/**\n',1)]
    for mutant in mutants:
        assert mutant!=text
        try:historical_parent(PATH,mutant)
        except ValueError:pass
        else:raise AssertionError('Foreign workflow or partial checkout accepted')
    return dict(status='TWO_EXACT_CHECKOUT_BLOCKS_WHOLE_ORIGINAL_WORKFLOW_BODY_AND_FIVE_REAL_MUTANT_REFUSALS_PASS',
        actual_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),workflow=PATH,
        actual_working_LF_sha256=SHA(raw),actual_original_sha256=SHA(original),complete_original_workflow_bytes_preserved=True,
        changed_checkout_blocks=2,actual_mutant_refusals=len(mutants),qualification_commands_changed=False,compiler_executions=0,model_executions=0)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=audit()
    with a.output.open('x',encoding='utf8') as out:json.dump(q,out,indent=2);out.write('\n')
    print(q['status'],flush=True)
