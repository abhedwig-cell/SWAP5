"""V3 corrected research: one current profile-derived matrix/macropore view."""
import json,sys
from pathlib import Path
import build_joint_contact_candidate as contact
from build_joint_entry_candidate import ROOT,once,sha
MODEL='ANDELST_JOINT_CURRENT_GROUNDWATER_GRAPH_V3'

def render(folder):
 shadow=contact.render(folder)
 name='src/runtime/mod_macropore_standard_rate_adapter.f90'
 s=(ROOT/name).read_text()
 s=once(s,'  implicit none','  use mod_b111_profile_groundwater_projection\n  implicit none')
 s=once(s,'    real(real64)::gwl,upper,lower',
  '    real(real64)::gwl,upper,lower,distance(size(z))\n    type(b111_profile_groundwater_projection_t)::projection')
 s=once(s,'    gwl=matrix%groundwater_level', '''    distance=0d0;distance(2:n)=abs(z(2:n)-z(1:n-1))
    call evaluate_b111_profile_groundwater_projection(z,distance,matrix%pressure_head,matrix%ponding_depth,projection)
    if(.not.projection%valid)return
    if(.not.projection%level_present)then
      view%valid=.true.
      return
    end if
    gwl=projection%level_cm''')
 s=once(s,'    request%matrix_sat%matrix_level=matrix%groundwater_level',
  '    request%matrix_sat%matrix_level=matrix_view%groundwater_level_cm')
 target=folder/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(s,newline='\n');shadow[ROOT/name]=target
 name='src/legacy/b1_10_port/headcalc.f90';s=shadow[ROOT/name].read_text()
 s=once(s,'   use mod_reference_bordered_solver,only:reference_bordered_solve',
  '   use mod_reference_bordered_solver,only:reference_bordered_solve\n   use mod_b111_profile_groundwater_projection')
 s=once(s,(ROOT/'tests/dataqual15/research/joint_contact_headcalc.inc').read_text(),
  (ROOT/'tests/dataqual15/research/joint_current_view_headcalc.inc').read_text())
 shadow[ROOT/name].write_text(s,newline='\n')
 p=folder/'MODEL.json';record=json.loads(p.read_text());record.update(model=MODEL,
  groundwater='Existing CALCGWL profile projection from current residual candidate; no lagged groundwater field.',
  rendered_sources_sha256={str(n.relative_to(ROOT)):sha(p.read_bytes())for n,p in shadow.items()})
 p.write_text(json.dumps(record,indent=2)+'\n');return shadow

if __name__=='__main__':
 contact.base.render=render
 contact.base.main()
 p=Path(sys.argv[sys.argv.index('--output')+1])/'BUILD.json';record=json.loads(p.read_text())
 record['contact_model']=MODEL;p.write_text(json.dumps(record,indent=2)+'\n')
