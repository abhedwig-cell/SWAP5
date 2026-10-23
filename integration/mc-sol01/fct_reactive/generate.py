"""Exact, asserted transformations of source-bound real physics and fixtures."""
import runpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
PHYSICAL='src/process/mod_b111_reactive_solute_substep.f90'
STORAGE='integration/mc-sol01/fct_water_sorption/mod_research_storage_fct.f90'
TRACE='integration/mc-sol01/fct_accepted_trace/mod_research_trace_replay.f90'
JOINT='integration/mc-sol01/fct_joint_acceptance/mod_research_joint_fct.f90'
def replace(text,old,new,count=1):
    assert text.count(old)==count,(old,text.count(old),count)
    return text.replace(old,new)
def physical():
    text=(ROOT/PHYSICAL).read_text()
    begin=text.index('  integer,parameter,public::B111_REACTIVE_OK=0')
    end=text.index('  public::advance_b111_reactive_solute_substep')
    text=text[:begin]+text[end:]
    imports='  use mod_b111_reactive_solute_substep,only: b111_reactive_solute_substep_forcing_t, &\n       b111_reactive_solute_substep_receipt_t,B111_REACTIVE_OK,B111_REACTIVE_INVALID, &\n       B111_REACTIVE_STATE_MISMATCH,B111_REACTIVE_NEGATIVE,B111_REACTIVE_PARTITION, &\n       B111_REACTIVE_BALANCE,B111_REACTIVE_NOCONV,B111_TRANSPORT_REFERENCE,B111_TRANSPORT_IMPLICIT_UPWIND\n'
    text=replace(text,'  implicit none',imports+'  implicit none')
    text=replace(text,'module mod_b111_reactive_solute_substep','module mod_research_corrected_reactive')
    text=replace(text,'advance_b111_reactive_solute_substep','advance_research_corrected_reactive',2)
    text=replace(text,'receipt,exact_empty_pond_limit)','receipt,exact_empty_pond_limit,mass_correction)',2)
    text=replace(text,'r,exact_empty_pond_limit)','r,exact_empty_pond_limit,mass_correction)')
    text=replace(text,'    logical,intent(in),optional::exact_empty_pond_limit',
        '    logical,intent(in),optional::exact_empty_pond_limit\n    real(real64),intent(in),optional::mass_correction(:)',2)
    text=replace(text,'    if(.not.b111_reactive_forcing_valid(f))return',
        '    if(.not.b111_reactive_forcing_valid(f))return\n    if(present(mass_correction))then\n      if(f%transport_scheme/=B111_TRANSPORT_IMPLICIT_UPWIND)return\n    end if')
    text=replace(text,'    source(1)=source(1)+pond%soil_transfer',
        '''    if(present(mass_correction))then
      if(size(mass_correction)/=n)return
      if(.not.all(ieee_is_finite(mass_correction)))return
      if(abs(sum(mass_correction))>8192d0*epsilon(1d0)*max(1d0,sum(initial)))return
      source=source+mass_correction
      if(any(source<0d0))return
    end if
    source(1)=source(1)+pond%soil_transfer''')
    return text.encode()
def storage():
    return runpy.run_path(str(HERE.parent/'fct_accepted_trace/qualify_replay.py'))['storage_successor']()
def trace():
    text=(ROOT/TRACE).read_text().replace('mod_research_trace_replay','mod_research_reactive_trace')
    text=text.replace('use mod_research_storage_fct','use mod_research_composed_fct')
    text=text.replace('advance_research_storage_fct','advance_research_composed_fct')
    text=text.replace('ledger(4)','ledger(5)').replace('account(4)\n','account(5)\n')
    text=replace(text,'   account(3)=max(account(3),abs(r%balance_residual_mg_cm2))',
        '   account(3)=max(account(3),abs(r%balance_residual_mg_cm2))\n   account(5)=account(5)+r%decay_output_mg_cm2')
    return text.encode()
def joint():
    text=(ROOT/JOINT).read_text().replace('mod_research_joint_fct','mod_research_joint_reactive_fct')
    text=text.replace('use mod_research_trace_replay','use mod_research_reactive_trace')
    return text.replace('ledger(4)','ledger(5)').replace('account(4)','account(5)').encode()
def driver():
    text=runpy.run_path(str(HERE.parent/'fct_joint_acceptance/run.py'))['generated_driver']().decode()
    text=text.replace('use mod_research_joint_fct','use mod_research_joint_reactive_fct')
    text=replace(text,'model%dispersivity_cm=0d0*model%face_distance_cm;',
        'model%decpot=.05d0+0d0*theta;model%molecular_diffusion_cm2_day=.02d0;model%dispersivity_cm=.25d0+0d0*model%face_distance_cm;')
    text=replace(text,'models(nt)%decpot(1)=.01d0','models(nt)%decpot(1)=-.01d0')
    text=replace(text,'maxval(abs(jr%ledger(3:)))','maxval(abs(jr%ledger(3:4)))')
    text=replace(text,"3(I0,1X),4(ES25.16E3,1X))','WINDOW'","3(I0,1X),5(ES25.16E3,1X))','WINDOW'")
    text=replace(text,"  if(jr%status/=RESEARCH_JOINT_OK.or.jr%completed/=nt)error stop 'retry commit'",
        "  if(jr%status/=RESEARCH_JOINT_OK.or.jr%completed/=nt)error stop 'retry commit'\n  if(jr%ledger(5)<=0d0.or.jr%ledger(2)<jr%ledger(5))error stop 'decay execution'")
    return text.encode()
def sources():
    return {'corrected_reactive.f90':physical(),'storage_successor.f90':storage(),
        'reactive_trace.f90':trace(),'joint_reactive.f90':joint(),'joint_driver.f90':driver()}
