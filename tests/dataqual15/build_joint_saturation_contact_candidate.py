"""Private V6: sharp saturated exchange at zero matrix pressure in the joint solve.

The fraction is trial-local, with exact zero-head publication. No default
production source, tolerance, physical endpoint, or persisted schema changes.
"""
import json, sys
from pathlib import Path
import build_joint_bottom_contact_candidate as previous
from build_joint_entry_candidate import ROOT, once, sha

MODEL = 'ANDELST_JOINT_ZERO_HEAD_SATURATION_CONTACT_V6'


def render(folder):
    shadow = previous.render(folder)
    name = 'src/process/macropore/mod_ppa_wu05a6_saturated_exchange_rate.f90'
    s = (ROOT/name).read_text()
    s = once(s, '  implicit none', '  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite\n  implicit none')
    s = once(s, '    integer :: swsep = 0',
             '    real(real64), allocatable :: zero_head_fraction(:)\n    integer :: swsep = 0')
    s = once(s, '    nd=self%num_domains', '''    if(allocated(self%zero_head_fraction))then
      ok=.false.
      if(size(self%zero_head_fraction)/=self%num_nodes)return
      if(any(.not.ieee_is_finite(self%zero_head_fraction)))return
      if(any(.not.(self%zero_head_fraction>=-1d0.and.self%zero_head_fraction<=1d0)))return
    end if
    nd=self%num_domains''')
    s = once(s, '        hma=request%matrix_head(ic)', '''        hma=request%matrix_head(ic)
        if(allocated(request%zero_head_fraction))then
          if(request%zero_head_fraction(ic)>=0d0)hma=max(0d0,hma)
        end if''')
    s = once(s, '        result%signed_matrix_to_macro_amount_cm(id,ic)=signed_amount', '''        if(allocated(request%zero_head_fraction))then
          if(request%zero_head_fraction(ic)>=0d0)signed_amount=request%zero_head_fraction(ic)*signed_amount
        end if
        result%signed_matrix_to_macro_amount_cm(id,ic)=signed_amount''')
    target=folder/name;target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(s,newline='\n');shadow[ROOT/name]=target

    name='src/runtime/mod_ppa_wu05a16_inner_macropore_provider.f90'
    s=shadow[ROOT/name].read_text()
    s=once(s,'perched_fraction(:),bottom_fraction(:)','perched_fraction(:),bottom_fraction(:),zero_head_fraction(:)')
    s=once(s,'    self%configured=.true.','''    if(allocated(self%zero_head_fraction))deallocate(self%zero_head_fraction)
    allocate(self%zero_head_fraction(size(dz)));self%zero_head_fraction=-1d0
    self%configured=.true.''')
    s=once(s,'    call evaluate_macropore_rate_bundle(request,rates)','''    if(allocated(self%zero_head_fraction))then
      request%matrix_sat%zero_head_fraction=self%zero_head_fraction
      request%interflow_sat%zero_head_fraction=self%zero_head_fraction
    end if
    call evaluate_macropore_rate_bundle(request,rates)''')
    shadow[ROOT/name].write_text(s,newline='\n')

    name='src/runtime/mod_macropore_single_column_runtime.f90'
    s=shadow[ROOT/name].read_text();marker='      call evaluate_macropore_rate_bundle(rate_request,raw_rates)'
    s=s.replace(marker,'''      if(any(inner_provider%zero_head_fraction>=0d0))then
        if(any(abs(corrector%candidate_state%pressure_head)>1d-12.and.inner_provider%zero_head_fraction>=0d0))then
          result%status=MACRO_RUNTIME_RETRY;return
        end if
        rate_request%matrix_sat%zero_head_fraction=inner_provider%zero_head_fraction
        rate_request%interflow_sat%zero_head_fraction=inner_provider%zero_head_fraction
      end if
'''+marker,1)
    shadow[ROOT/name].write_text(s,newline='\n')

    name='src/legacy/b1_10_port/headcalc.f90';s=shadow[ROOT/name].read_text()
    s=once(s,'saved_bottom(:),weights(:)','saved_bottom(:),saved_zero(:),weights(:)')
    s=once(s,'  saved_bottom=mp%bottom_fraction','  saved_zero=mp%zero_head_fraction\n  saved_bottom=mp%bottom_fraction')
    s=once(s,'allocate(nodes(2*n),threshold(n),x(n),lambda(2*n),r(n),rp(n),rm(n),trial(n),candidate(2*n)',
           'allocate(nodes(3*n),threshold(n),x(n),lambda(3*n),r(n),rp(n),rm(n),trial(n),candidate(3*n)')
    marker='  allocate(gwl_distance(n),gwl_z(n));gwl_distance=0d0'
    s=once(s,marker,'''  ! Saturated transfer has the literal h<0 exclusion. Its one-sided
  ! endpoints bracket a contact action at h=0, independently of face contacts.
  do i=2,n-1
   if(abs(x(i))>1d-3)cycle
   k=k+1;nodes(k)=2*n+i;x(i)=0d0;lambda(k)=0d0
   call joint_entry_residual(x,lambda(:k),nodes(:k),rp,valid)
   if(.not.valid)then
    k=k-1;x(i)=saved_state%h(i);cycle
   end if
   lambda(k)=1d0;call joint_entry_residual(x,lambda(:k),nodes(:k),rm,valid)
   if(.not.valid.or.abs(rm(i)-rp(i))<1d-10)then
    k=k-1;x(i)=saved_state%h(i);cycle
   end if
   if(rp(i)*rm(i)>0d0)then
    k=k-1;x(i)=saved_state%h(i);cycle
   end if
   lambda(k)=min(1d0,max(0d0,-rp(i)/(rm(i)-rp(i))))
  end do
'''+marker)
    s=once(s,'  mp%bottom_fraction=saved_bottom','  mp%zero_head_fraction=saved_zero\n  mp%bottom_fraction=saved_bottom')
    s=once(s,'mp%bottom_fraction=-1d0','mp%bottom_fraction=-1d0;mp%zero_head_fraction=-1d0')
    s=once(s,'   if(nodes(j)>NN)then','''   if(nodes(j)>2*NN)then
    mp%zero_head_fraction(nodes(j)-2*NN)=fraction(j)
   else if(nodes(j)>NN)then''')
    split=s.index('\nsubroutine joint_entry_residual(');outer,residual=s[:split],s[split:]
    for j in ('j','jj'):
        outer=outer.replace(f'i=abs(nodes({j}));if(i>n)i=i-n',f'i=abs(nodes({j}));if(i>2*n)i=i-n\n    if(i>n)i=i-n')
        outer=outer.replace(f'if(nodes({j})>0.and.nodes({j})<=n)then',f'if(nodes({j})>2*n)then\n    ctest(i,{j})=1d0\n   else if(nodes({j})>0.and.nodes({j})<=n)then') if j=='j' else outer
    # The line-search projection of a zero-head contact is distinct from a face.
    outer=once(outer,'      if(nodes(jj)>0.and.nodes(jj)<=n)then','''      if(nodes(jj)>2*n)then
       trial(i)=0d0
      else if(nodes(jj)>0.and.nodes(jj)<=n)then''')
    outer=once(outer,'if(nodes(j)<0.or.nodes(j)>n)then','if(nodes(j)<0.or.(nodes(j)>n.and.nodes(j)<=2*n))then')
    s=outer+residual
    shadow[ROOT/name].write_text(s,newline='\n')
    p=folder/'MODEL.json';record=json.loads(p.read_text())
    record.update(model=MODEL,zero_head_contact='Trial-local saturated exchange fraction at exact zero head; same signed conservative transfer in residual and publication; no persisted fraction.',
                  rendered_sources_sha256={str(n.relative_to(ROOT)):sha(p.read_bytes())for n,p in shadow.items()})
    p.write_text(json.dumps(record,indent=2)+'\n')
    return shadow


if __name__=='__main__':
    previous.drainage.current.contact.base.render=render
    previous.drainage.current.contact.base.main()
    p=Path(sys.argv[sys.argv.index('--output')+1])/'BUILD.json'
    r=json.loads(p.read_text());r['contact_model']=MODEL;p.write_text(json.dumps(r,indent=2)+'\n')
