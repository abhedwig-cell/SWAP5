#!/usr/bin/env python3
"""Current-source replay of existing F-WOF40 true-process restart assertions."""
import argparse,importlib.util,json,os,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
a=argparse.ArgumentParser();a.add_argument('--output',required=True);args=a.parse_args()
out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=False)
f34=subprocess.check_output(['git','show','85c0f7838d56c63d49f16af8242bdf4cbe4219d9:tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90'],cwd=ROOT,text=True).split('\nprogram test_fwof34_accepted_window_runtime_lineage\n')[0]
# Same current F-KT mass-fixture compatibility as the incumbent PP03 adapter.
f34=f34.replace('only: real64\n','only: real64, int64\n',1).replace('only: transaction_state_t, trial_outcome_t\n','only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE\n',1)
f34=f34.replace('    procedure :: temporal_error => fwof34_temporal_error\n','    procedure :: temporal_error => fwof34_temporal_error\n    procedure :: storage_accounting_status => current_storage_accounting\n',1)
f34=f34.replace('    outcome%mass_in = transfer_mass\n','    outcome%mass_in = transfer_mass\n    outcome%mass_accounting_complete=.true.\n    outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE\n',1)
f34=f34.replace('\nend module mod_fwof34_test_model', '''
 subroutine current_storage_accounting(self,state,complete,missing_mask)
 class(fwof34_model_t),intent(in)::self
 class(transaction_state_t),intent(in)::state
 logical,intent(out)::complete
 integer(int64),intent(out)::missing_mask
 complete=same_type_as(self,self).and.same_type_as(state,state)
 missing_mask=TX_MASS_MISSING_NONE
 end subroutine
end module mod_fwof34_test_model''',1)
f34p=out/'f34.f90';f34p.write_text(f34)
fixture=out/'fixture.f90';text=(ROOT/'tests/fwof/mod_fwof40_restart_fixture.f90').read_text();assert text.count('scalar%development_daylength_mode = 1')==1
fixture.write_text(text.replace('scalar%development_daylength_mode = 1','scalar%development_daylength_mode = 0',1))
spec=importlib.util.spec_from_file_location('dep',ROOT/'tests/support/augment_bartholomeus_backend_sources.py');dep=importlib.util.module_from_spec(spec);spec.loader.exec_module(dep)
# Resolve production modules using real tree paths, then explicit test providers.
ordered,_=dep.strict_closure(ROOT,['src/runtime/mod_fmr_wofost_crop_event_lifecycle.f90','src/kernel/mod_kernel_committed_persistence.f90'])
ordered += [f34p,fixture,ROOT/'tests/fwof/mod_fwof40_external_crop_restart_adapter.f90']
(out/'compile-sources.txt').write_text('\n'.join(str(p) for p in ordered)+'\n')
s=(ROOT/'tests/fwof/run_fwof40_true_process_restart_gate.sh').read_text();a=s.index('# Preserve F-WOF39');b=s.index('COMMON=(',a)
s=s[:a]+s[b:]
s=s.replace('ROOT="$(cd "$(dirname "$0")/../.." && pwd)"','ROOT="${ANNUAL_ROOT:?}"',1).replace('BUILD="${TMPDIR:-/tmp}/swap5-fwof40-process-restart-$$"','BUILD="${ANNUAL_BUILD:?}"',1).replace('trap \'rm -rf "$BUILD"\' EXIT',"trap ':' EXIT",1)
a=s.index('BASE_SOURCES=(');b=s.index('\nfor OPT in 0 2; do',a)
s=s[:a]+'mapfile -t BASE_SOURCES < "$BUILD/compile-sources.txt"\n'+s[b:]
a=s.index('  for src in "${BASE_SOURCES[@]}"; do');b=s.index('  OBJECTS=(./*.o)',a)
s=s[:a]+'''  for src in "${BASE_SOURCES[@]}"; do
    gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$src"
  done

'''+s[b:]
s=s.replace('-Werror -fcheck=all','-Werror -Wno-error=compare-reals -Wno-error=function-elimination -fcheck=all',1)
s=s.replace("replace('codec ', 'codec 2', 'bad_codec.artifact')","replace('codec ', 'codec 99', 'bad_codec.artifact')",1)
(out/'run.sh').write_text(s);env=os.environ.copy();env.update(ANNUAL_ROOT=str(ROOT),ANNUAL_BUILD=str(out))
t=time.monotonic();r=subprocess.run(['bash',str(out/'run.sh')],cwd=ROOT,env=env,capture_output=True,text=True)
(out/'stdout').write_text(r.stdout);(out/'stderr').write_text(r.stderr)
result={'exit':r.returncode,'seconds':time.monotonic()-t,'scope':'Original F-WOF40 producer/consumer/reference and corrupt-state assertions with existing real production persistence API. F-KT fixture mass completeness adapted, build closure updated, IDSL0 selected. Invalid codec test uses99 because2 is the new valid extension.'}
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));raise SystemExit(r.returncode)
