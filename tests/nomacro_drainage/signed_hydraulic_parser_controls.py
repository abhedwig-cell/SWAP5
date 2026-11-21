"""Exercise the actual shared parser and preserve its unchanged unsigned domain."""
import argparse
import ast
from dataclasses import replace
import json
from pathlib import Path
import sys
import types

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import experimental_project as frontend
import model7_capacity as current
import model7_terminal_water as terminal
from original_output_baseline import assignment
from signed_hydraulic_source_inverse import complete_inverse,blob,PARENT,PATH


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    complete_inverse();a.output.mkdir()
    project=frontend.load(a.input,original_output=True,time_step_policy='original-adaptive-day-seed-v1')
    raw=(a.input/'swap.swp').read_text(encoding='cp1252')
    old=types.ModuleType('old_model7_capacity');old.__file__=str(ROOT/PATH);exec(compile(blob(PARENT,PATH),PATH,'exec'),old.__dict__)
    controls=[]
    cases=[(str(n),(n,)) for n in range(1,12)]+[('+'+str(n),(n,)) for n in range(1,12)]
    cases += [('7 8',(7,8)),('+7 +8',(7,8)),('7 +8',(7,8)),('+7 8',(7,8)),('+0007 +0008',(7,8))]
    cases += [(value,None) for value in ('-8','0','+0','12','+12','8.0','8,11','8 +','--8','++8','')]
    for index,(literal,expected) in enumerate(cases):
        directory=a.output/str(index);directory.mkdir();path=directory/'swap.swp'
        path.write_text(assignment(raw,'iHWCKmodel',literal),encoding='cp1252')
        candidate=replace(project,input_directory=str(directory.resolve()))
        result=current.analytical_models(candidate);assert result==expected,(literal,result,expected)
        assert current.enabled(candidate)==bool(expected and 7 in expected)
        assert terminal.enabled(candidate)==bool(expected and any(n>=3 for n in expected))
        prior=old.analytical_models(candidate)
        if '+' not in literal:assert prior==result
        controls.append(dict(literal=literal,parsed=result,previous=prior,capacity=current.enabled(candidate),terminal=terminal.enabled(candidate)))
    record=dict(status='ACTUAL_SIGNED_HYDRAULIC_PARSER_AND_UNCHANGED_UNSIGNED_DOMAIN_PASS',checks=controls,
        cases=len(controls),compiler_executions=0,model_executions=0,claim='Parser and dispatch only; original reader startup and integrated postimages are separate evidence',canonical_admission=False)
    (a.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],len(controls))


if __name__=='__main__':main()
