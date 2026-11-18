"""Actual private CDE candidate stock/receipt probe before groundwater expansion."""
import argparse
import json
from pathlib import Path
import struct
import subprocess
import zipfile
import original_output_matrix as matrix
from daily_coupling import CoupledDailyColumn

m=matrix.m


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','profile-root','input-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();project=m.e.load(a.input_root,original_output=True);build=a.profile_root/'build';m.validate_bundle(build,a.reference_work,project);source=a.profile_root/'trajectory/accepted-column-1-day-4.zip';digest=m.sha(source)
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=matrix.ROOT,text=True).strip(),source_checkpoint_sha256=digest,build_sha256=m.sha(build/'BUILD.json'),published=False,diagnostic='Private prepare only; no accepted external state is published; actual old build/input/checkpoint bytes retained')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        positive=CoupledDailyColumn(build,a.reference_work,a.output/'positive',project,'cde-stock-probe',origin=source,day=4,adopt_native=True);trial=positive.prepare();candidate=positive._candidate[3]
        with zipfile.ZipFile(candidate) as z:actual=struct.unpack_from('<d',z.read('macro.bin'),48+8*(project.nodes+1))[0]
        assert actual==trial.budget['solute_end_mg_cm2'] and positive.day==4
        q['positive']=dict(actual_native_stock_mg_cm2=actual,reported_stock_mg_cm2=trial.budget['solute_end_mg_cm2'],source_unchanged=m.sha(source)==digest,private_candidate=str(candidate));save()
        negative=CoupledDailyColumn(build,a.reference_work,a.output/'reported-mismatch',project,'cde-stock-probe',origin=source,day=4,adopt_native=True);receive=m.h.receive;changed=[False]
        def corrupt(process,*args,**kwargs):
            disposition,response=receive(process,*args,**kwargs)
            if not changed[0] and 'HYBRID_DAY_RETURN' in response and 'HYBRID_SOLUTE_LEDGER' in response:
                values=response['HYBRID_SOLUTE_LEDGER'].copy();values[0]=str(float(values[0])+1.);values[2]=str(float(values[2])+1.);response['HYBRID_SOLUTE_LEDGER']=values;changed[0]=True
            return disposition,response
        try:
            m.h.receive=corrupt
            try:proposal=negative.prepare()
            except (ValueError,RuntimeError) as error:
                assert changed[0];q['negative']=dict(status='REFUSED_BEFORE_EXTERNAL_PREPARED_CANDIDATE',error=str(error))
            else:
                candidate=negative._candidate[3]
                with zipfile.ZipFile(candidate) as z:actual=struct.unpack_from('<d',z.read('macro.bin'),48+8*(project.nodes+1))[0]
                assert actual!=proposal.budget['solute_end_mg_cm2'];q['negative']=dict(status='PREPARED_PRIVATE_CANDIDATE_NATIVE_STOCK_RECEIPT_MISMATCH',actual_native_stock_mg_cm2=actual,reported_stock_mg_cm2=proposal.budget['solute_end_mg_cm2'],reported_chemical_residual_mg_cm2=proposal.budget['solute_independent_residual_mg_cm2'],private_candidate=str(candidate),source_state_advanced=False)
        finally:m.h.receive=receive
        assert changed[0] and negative.day==4 and positive.day==4 and m.sha(source)==digest
        q['status']='ACTUAL_CDE_PRIVATE_NATIVE_RECEIPT_DIAGNOSTIC_COMPLETE';print(json.dumps(q,indent=2),flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
