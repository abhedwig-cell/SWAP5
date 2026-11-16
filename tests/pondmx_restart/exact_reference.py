"""Unmodified431 on literal executed worker inputs, including native output mode."""
from pathlib import Path
import importlib.util,json,shutil,sys
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('mixtures',ROOT/'tests/nomacro_mixtures/run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


def compare(full,reference,out):
    out.mkdir(parents=True,exist_ok=False);inputs=out/'inputs';inputs.mkdir()
    meta=json.loads((full/'BUILD.json').read_text());worker=full/'original'
    actual={}
    for name in meta['inputs']:
        source=worker/name;target=inputs/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
        actual[name]=m.sha(source);assert m.sha(target)==actual[name]
    result=m.reference_run(inputs,reference,out/'original431',full,20)
    assert result['identical_executed_inputs']==actual
    assert all(m.sha(out/'original431'/name)==digest for name,digest in actual.items())
    assert result['status']=='COMPLETE_DIAGNOSTIC_REFERENCE'
    result['actual_worker_input_sha256']=actual
    result['literal_worker_inputs_exact']=True
    result['SWENDTYPE']=2
    (out/'RESULT.json').write_text(json.dumps(result,indent=2))
    return result


def main():
    root=Path(sys.argv[1]);reference=Path(sys.argv[2]);out=Path(sys.argv[3]);out.mkdir(parents=True,exist_ok=False)
    reports={}
    for kind in ('water','chemical'):
        key=kind+'-surface-history';reports[key]=compare(root/(key+'-O2-full'),reference,out/key)
        previous=root/(key+'-original431/result_output.csv')
        reports[key]['prior_output_compatible_csv_exact']=m.csvlines(previous)==m.csvlines(out/key/'original431/result_output.csv')
        assert reports[key]['prior_output_compatible_csv_exact'],'Output-mode change affected original trajectory'
        print(key,'LITERAL_EXECUTED_WORKER_REFERENCE_FULL_PASS',flush=True)
    (out/'RESULT.json').write_text(json.dumps(dict(status='LITERAL_WORKER_INPUTS_ORIGINAL431_FULL_COMPARISON_PASS',reports=reports,earlier_comparison='Preserved separately: source deck used SWENDTYPE1 while actual worker used2; output-only discrepancy, not literal input equality'),indent=2))


if __name__=='__main__':main()
