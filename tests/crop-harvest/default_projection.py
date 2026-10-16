"""Reviewed absent-harvest/false-fallow projection; not a general Fortran parser.

Projection proves incumbent branches only. Exact postimages plus scientific
qualification independently bind every projected-away optional implementation.
"""
import re
BASE='47b652248420ba7c49df7e063c64ff749ce6253f'

def replace(s,new,old='',count=1):
 if s.count(new)!=count:raise ValueError('unknown projection edit '+new[:90])
 return s.replace(new,old)
def cut(s,start,end):
 if s.count(start)!=1:raise ValueError('ambiguous projection boundary '+start)
 a=s.index(start);b=s.index(end,a);return s[:a]+s[b:]
def routine(s,name,kind='subroutine'):
 pattern=r'^\s{1,2}'+kind+r' '+name+r'\(.*?^\s{1,2}end '+kind+r'[^\n]*\n'
 s,n=re.subn(pattern,'',s,flags=re.M|re.S)
 if n!=1:raise ValueError('routine projection '+name)
 return s

def owner(s):
 s=replace(s,'  use iso_fortran_env, only: real64,int64\n  use ieee_arithmetic, only: ieee_is_finite\n')
 s=cut(s,'  integer, parameter, public :: WOFOST81_HARVEST_INVALID','  type, extends(transaction_state_t)')
 # The baseline retains a blank line between constants and its owner type.
 for line in ['    type(wofost81_harvest_record_t), allocatable, private :: harvest\n','    type(wofost81_harvest_retired_t), allocatable, private :: retired\n',
 '    procedure, public :: harvest_snapshot => snapshot_harvest\n','    procedure, public :: harvested => crop_harvested\n',
 '    procedure, public :: retired_snapshot => snapshot_retired\n','    procedure, public :: harvest_retired => crop_retired\n',
 '      if(allocated(self%harvest)) allocate(typed_copy%harvest,source=self%harvest)\n','      if(allocated(self%retired)) allocate(typed_copy%retired,source=self%retired)\n']:
  s=replace(s,line)
 for condition in ['retired','harvest']:
  a=s.index('    if(allocated(self%'+condition+')) then');b=s.index('    end if\n',a)+len('    end if\n');s=s[:a]+s[b:]
 s=cut(s,'  logical function crop_harvested','end module mod_wofost81_crop_owner_state')
 return s

def configuration(s):
 s=replace(s,' use mod_wofost81_crop_owner_state,only:wofost81_harvest_policy_t\n')
 s=cut(s,' type,public::crop_n_harvest_configuration_t',' type,public::crop_n_configuration_t')
 s=replace(s,'  type(crop_n_harvest_configuration_t),allocatable::harvest\n')
 a=s.index('  if(allocated(p%harvest))then');b=s.index(' end function',a);return s[:a]+s[b:]

def day(s):
 s=replace(s,',soil_n_transfer_t,soil_n_receipt_t,apply_soil_n_transfer,SOIL_N_OK')
 s=replace(s,',build_pending_residue_materials')
 s=replace(s,' use mod_wofost81_harvest_materials\n use mod_b111_soil_n_addition\n')
 s=cut(s,' type,public::crop_soil_harvest_observation_t',' type,public::crop_soil_receipt_t')
 for line in [' public::harvest_crop_soil_boundary,consume_crop_soil_harvest_pending,crop_soil_whole_n\n',
 ' public::observe_crop_soil_harvest,acknowledge_crop_soil_harvest,advance_crop_soil_fallow_day,initialize_crop_soil_successor\n',
 ' public::pack_crop_n_continuation,unpack_crop_n_continuation,harvest_incorporation_valid\n']:
  s=replace(s,line)
 # Baseline coupled readiness did not validate crop until its constructor/packer.
 # For valid incumbent owners this extra predicate is already satisfied.
 s=replace(s,'  ok=self%crop%validate()==0\n  if(.not.ok)return\n')
 s=cut(s,'  if(self%crop%harvest_retired())then','  if(allocated(self%pending))then')
 s=replace(s,'  v=pack_crop_n_continuation(crop)','  v=pack_crop_n_owner(crop)')
 s=replace(s,'  end if\n  if(.not.state%ready())then;state=crop_soil_state_t();return;end if\n  status=CROP_SOIL_OK','  end if\n  status=CROP_SOIL_OK')
 s=cut(s,'\n real(real64)function crop_soil_organic_mass','\nend module')
 s=replace(s,' end subroutine\n\nend module',' end subroutine\nend module')
 return s

def senescence(s):
 return replace(s,'''  block
   type(reactive_state_t)::soil
   type(wofost81_crop_owner_state_t)::crop
   call state%snapshot(soil,crop)
   if(crop%harvested())then;ok=harvest_incorporation_valid(state);return;end if
  end block
''')
def one_day(s):return replace(s,'    if (committed%harvested()) return\n')

def application(s):
 s=replace(s,',run_crop_soil_n_harvest_boundary')
 s=routine(s,'run_crop_soil_n_harvest_boundary')
 s=replace(s,'result,environment,fallow)','result,environment)')
 s=replace(s,'    logical,intent(in),optional::fallow\n')
 s=replace(s,'logical::ok,did_commit,inactive','logical::ok,did_commit')
 s=replace(s,'    inactive=.false.;if(present(fallow))inactive=fallow\n')
 a=s.index('    if(inactive)then');b=s.index('    end if\n',a)+len('    end if\n');s=s[:a]+s[b:]
 a=s.index('    if(inactive)then');b=s.index('    else\n',a)+len('    else\n');s=s[:a]+s[b:]
 s=replace(s,'weather,result%chemical,environment)\n    end if','weather,result%chemical,environment)')
 return s

def codec(s):
 for line in ["  character(8),parameter::HARVEST_MAGIC='S5NC0005',HARVEST_PENDING_MAGIC='S5NC0006'\n", "  character(8),parameter::HEAT_HARVEST_MAGIC='S5NC0007',HEAT_HARVEST_PENDING_MAGIC='S5NC0008'\n"]:s=replace(s,line)
 s=cut(s,'  logical function pending_tag','  subroutine write_crop_soil_n_joint_restart_file')
 a=s.index('    if(crop%harvested())then');b=a+re.search(r'^    end if\n',s[a:],re.M).end();s=s[:a]+s[b:]
 s=replace(s,'pack_crop_n_continuation(crop)','pack_crop_n_owner(crop)')
 s=replace(s,'thermal=thermal_tag(tag)','thermal=tag==HEAT_MAGIC.or.tag==HEAT_PENDING_MAGIC')
 s=replace(s,'.and..not.harvest_tag(tag)')
 s=replace(s,'count<9','count<29')
 s=replace(s,'if(pending_tag(tag))then','if(tag==PENDING_MAGIC.or.tag==HEAT_PENDING_MAGIC)then',2)
 s=replace(s,'unpack_crop_n_continuation(ov,crop_trial,io)','unpack_crop_n_owner(ov,crop_trial,io)')
 return replace(s,'        if(crop_trial%harvested().neqv.harvest_tag(tag))exit decoding\n')

PROJECTORS={'src/crop/mod_wofost81_crop_owner_state.f90':owner,'src/crop/mod_crop_soil_n_configuration.f90':configuration,
 'src/crop/mod_crop_soil_n_day.f90':day,'src/crop/mod_crop_soil_n_senescence_day.f90':senescence,
 'src/crop/mod_wofost81_one_day_candidate.f90':one_day,'src/runtime/mod_fmr_crop_soil_n_joint_application.f90':application,
 'src/adapter/mod_crop_soil_n_joint_restart_file.f90':codec}

def validate(current,baseline):
 if set(current)!=set(PROJECTORS)or set(baseline)!=set(PROJECTORS):raise ValueError('projection surface')
 for path,project in PROJECTORS.items():
  if project(current[path])!=baseline[path]:raise ValueError('incumbent branch projection drift '+path)
 return True
