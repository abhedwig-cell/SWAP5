"""Try a branch-consistent Jacobian at the zero-inflow clamp."""
import json
import render_legacy_matrix_cap as cap
from build_joint_entry_candidate import ROOT, once, sha
import build_joint_upper_support_candidate as v9

def render(folder):
    shadow=cap.render(folder)
    src=ROOT/'src/process/macropore/mod_ppa_wu05a15_exchange_derivative.f90'
    path=folder/src.relative_to(ROOT)
    s=src.read_text()
    start=s.index('  subroutine project_conservative_storage_diagonal')
    a,b=s[:start],s[start:]
    b=once(b,'    integer::nd,n,id,ic','    integer::nd,n,id,ic\n    logical :: differentiate_inflow')
    needle='    do id=1,nd\n      if(rates%limiter%inflow_fraction(id)<1d0)then'
    b=once(b,needle,'''    do id=1,nd
      differentiate_inflow=rates%limiter%inflow_fraction(id)<1d0
      if(allocated(request%limiter%matrix_only_capacity_cm))then
        if(rates%limiter%inflow_fraction(id)==0d0)differentiate_inflow=.false.
      end if
      if(differentiate_inflow)then''')
    b=once(b,'        if(rates%limiter%inflow_fraction(id)<1d0)then','        if(differentiate_inflow)then')
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(a+b);shadow[src]=path
    manifest=folder/'MODEL.json';data=json.loads(manifest.read_text())
    data['rendered_sources_sha256']={str(k.relative_to(ROOT)):sha(p.read_bytes()) for k,p in shadow.items()}
    manifest.write_text(json.dumps(data,indent=2)+'\n')
    return shadow

if __name__=='__main__':
    base=v9.previous.previous.previous.previous.drainage.current.contact.base
    base.render=render
    base.main()
