"""Asserted successor; physical equations remain generated from production."""
import runpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
OLD=HERE.parent/'fct_reactive'
g=runpy.run_path(str(OLD/'generate.py'))
replace=g['replace']
def composed():
    text=(OLD/'mod_research_composed_fct.f90').read_text()
    text=text.replace('mod_research_composed_fct','mod_research_sink_fct').replace('advance_research_composed_fct','advance_research_sink_fct')
    text=replace(text,' use mod_research_storage_fct',' use mod_research_composed_fct\n use mod_research_storage_fct')
    text=replace(text,'  if(present(applied_correction))applied_correction=0d0*f%theta', '''  if(present(applied_correction))applied_correction=0d0*f%theta
  if(all(f%root_sink_cm_day==0d0).and.all(f%qdra_cm_day==0d0))then
   call advance_research_composed_fct(m,s,f,enabled,next,next_s,r,correction_l1,applied_correction);return
  end if
  if(.not.allocated(f%theta_previous))return
  if(any(f%qdra_cm_day<0d0).or.f%tscf>1d0)return
  n=size(f%theta)
  if(any(abs((f%theta-f%theta_previous)*f%dz_cm-f%dt_day* &
   (-f%q_face_up_cm_day(:n)+f%q_face_up_cm_day(2:)-f%root_sink_cm_day-sum(f%qdra_cm_day,dim=1)))> &
   2048d0*epsilon(1d0)*max(1d0,maxval(f%dz_cm),maxval(abs(f%dt_day*f%q_face_up_cm_day)))))return''')
    begin=text.index('  if(all(f%decpot==0d0)')
    end=text.index('  advection=f;',begin)
    text=text[:begin]+text[end:]
    text=replace(text,'  call advance_research_storage_fct(m,s,advection,.true.,high,high_s,r)', '''  ! Virtual carrier belongs to numerical scratch, never physical publication.
  advection%theta=f%theta_previous+f%dt_day* &
   (-f%q_face_up_cm_day(:n)+f%q_face_up_cm_day(2:))/f%dz_cm
  advection%root_sink_cm_day=0d0;advection%qdra_cm_day=0d0
  call advance_research_storage_fct(m,s,advection,.true.,high,high_s,r)''')
    return text.encode()
def trace():
    text=g['trace']().decode().replace('mod_research_reactive_trace','mod_research_sink_trace')
    text=text.replace('mod_research_composed_fct','mod_research_sink_fct').replace('advance_research_composed_fct','advance_research_sink_fct')
    text=text.replace('ledger(5)','ledger(7)').replace('account(5)\n','account(7)\n')
    text=replace(text,'   account(5)=account(5)+r%decay_output_mg_cm2', '''   account(5)=account(5)+r%decay_output_mg_cm2
   account(6)=account(6)+r%root_output_mg_cm2
   account(7)=account(7)+r%drain_output_mg_cm2''')
    return text.encode()
def joint():
    text=g['joint']().decode().replace('mod_research_joint_reactive_fct','mod_research_joint_sink_fct')
    text=text.replace('mod_research_reactive_trace','mod_research_sink_trace').replace('ledger(5)','ledger(7)').replace('account(5)','account(7)')
    text=replace(text,'if(code/=WATER_FACE_FLUX_OK.or.any(s%net_node_source/=0d0))then', '''if(code/=WATER_FACE_FLUX_OK.or.any(s%drainage_sink_by_level<0d0).or. &
     any(abs(s%net_node_source+s%root_sink+sum(s%drainage_sink_by_level,dim=1))>2048d0*epsilon(1d0)))then''')
    return text.encode()
def driver():
    text=g['driver']().decode().replace('mod_research_joint_reactive_fct','mod_research_joint_sink_fct')
    text=replace(text,' integer::nt,k,accepted,rejected',' integer::nt,k,accepted,rejected\n real(real64)::uptake')
    text=replace(text,' read(path,*)exponent',' call get_command_argument(4,arg);read(arg,*)uptake\n read(path,*)exponent')
    text=replace(text,'p%bottom_mode=2;', 'p%root_extraction_active=.true.;p%bottom_mode=2;')
    text=replace(text,'tile%base_forcing%drainage_flux_by_level=0d0','tile%base_forcing%drainage_flux_by_level=.002d0*40d0/nodes')
    text=replace(text,'tile%base_forcing%root_extraction_sink=0d0*theta','tile%base_forcing%root_extraction_sink=.003d0*dz')
    text=replace(text,' model%transport_scheme=B111_TRANSPORT_IMPLICIT_UPWIND',' model%tscf=uptake\n model%transport_scheme=B111_TRANSPORT_IMPLICIT_UPWIND')
    text=replace(text,"5(ES25.16E3,1X))','WINDOW'","7(ES25.16E3,1X))','WINDOW'")
    text=replace(text,"  if(jr%ledger(5)<=0d0.or.jr%ledger(2)<jr%ledger(5))error stop 'decay execution'", '''  if(jr%ledger(5)<=0d0.or.jr%ledger(7)<=0d0)error stop 'physical sink execution'
  if(uptake==0d0.and.jr%ledger(6)/=0d0)error stop 'water-only roots lost solute'
  if(uptake>0d0.and.jr%ledger(6)<=0d0)error stop 'root uptake absent'
  if(jr%ledger(2)<sum(jr%ledger(5:7)))error stop 'double sink ledger' ''')
    return text.encode()
def sources():
    return {'corrected_reactive.f90':g['physical'](),'storage_successor.f90':g['storage'](),
      'sink_composed.f90':composed(),'sink_trace.f90':trace(),'sink_joint.f90':joint(),'joint_driver.f90':driver()}
