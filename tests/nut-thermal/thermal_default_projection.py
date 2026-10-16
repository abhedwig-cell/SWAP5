"""Exact projection of the reviewed default branches; no general Fortran parser."""
import re

def replace(s,new,old='',count=1):
 if s.count(new)!=count:raise ValueError('unknown compatibility edit: '+new[:100])
 return s.replace(new,old)

def thermal_false(s):
 """Select only the reviewed literal if(thermal)then blocks, dedenting else."""
 lines=s.splitlines(keepends=True);out=[];i=0;blocks=0
 while i<len(lines):
  if lines[i].strip()!='if(thermal)then':out.append(lines[i]);i+=1;continue
  blocks+=1;depth=1;keep=False;i+=1
  while i<len(lines)and depth:
   line=lines[i];token=line.strip().lower()
   if token=='end if':
    depth-=1
    if depth==0:i+=1;break
   if depth==1 and token=='else':keep=True;i+=1;continue
   if keep:out.append(line[2:]if line.startswith('  ')else line)
   if re.match(r'if\s*\(',token)and token.endswith('then'):depth+=1
   i+=1
  if depth:raise ValueError('unterminated thermal branch')
 return ''.join(out),blocks

def project_backend(s):
 s=replace(s,'trace_accepted_water_flux_substeps,trace_accepted_soil_n_heat)','trace_accepted_water_flux_substeps)')
 s=replace(s,'    logical, intent(in), optional :: trace_accepted_soil_n_heat\n    logical :: soil_n_heat_trace\n')
 s=replace(s,'''    soil_n_heat_trace=.false.
    if(present(trace_accepted_soil_n_heat))soil_n_heat_trace=trace_accepted_soil_n_heat
    if(soil_n_heat_trace)then
      if(.not.self%model%accepted_water_flux_trace_enabled.or..not.parameters%soil_temperature_active.or. &
         parameters%frost_active.or.template%optional_state_layout_id/=FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE.or. &
         template%solute_state_layout_id/=FMR_SOLUTE_STATE_LAYOUT_NONE)then
        call reject_backend_trial(result,candidate,diagnostics)
        return
      end if
    end if
''')
 return replace(s,'FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED.and. &\n           .not.soil_n_heat_trace)','FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED)')

def project_matcher(s):
 s=replace(s,'  public::reactive_n_thermal_states_match\n')
 a=s.index('  logical function reactive_n_joint_states_match(')
 b=s.index('    class(transaction_state_t),allocatable::physical',a)
 if not s[a:b].startswith('''  logical function reactive_n_joint_states_match(water,chemical) result(ok)
    type(kernel_committed_state_t),intent(in)::water
    type(reactive_state_t),intent(in)::chemical
    ok=states_match(water,chemical,.false.)
  end function
'''):raise ValueError('BASE matcher must select false')
 s=s[:a]+'''  logical function reactive_n_joint_states_match(water,chemical) result(ok)
    type(kernel_committed_state_t),intent(in)::water
    type(reactive_state_t),intent(in)::chemical
'''+s[b:]
 s,n=thermal_false(s)
 if n!=2:raise ValueError('matcher thermal branch count')
 s=replace(s,'      call check(p)','      ok=bounded_physical(p,theta,parameters)',2)
 a=s.index('  contains\n    subroutine check(p)');b=s.index('    end subroutine\n',a)+len('    end subroutine\n')
 if s[a:b]!='''  contains
    subroutine check(p)
      class(fmr_b110_physical_state_t),intent(in)::p
      type(soil_temperature_field_view_t)::heat
      integer::code
      ok=bounded_physical(p,theta,parameters,thermal)
    end subroutine
''':raise ValueError('unknown default matcher helper')
 # This helper is private and its entire reviewed body is fixed by the
 # scientific postimage/evidence guard before projection is accepted.
 s=s[:a]+s[b:]
 s=replace(s,'bounded_physical(p,theta,parameters,thermal)','bounded_physical(p,theta,parameters)')
 s=replace(s,'    logical,intent(in)::thermal\n')
 return replace(s,'''         allocated(p%rutter))return
    if(.not.thermal.and.allocated(p%soil_temperature))return''','''         allocated(p%soil_temperature).or.allocated(p%rutter))return''')

def project_codec(s):
 s=replace(s,'''  use mod_kernel_transactions,only:kernel_committed_state_t,kernel_parameter_identity_t, &
       kernel_reconstruct_committed_state_trusted''','  use mod_kernel_transactions,only:kernel_committed_state_t')
 s=replace(s,'fmr_new_b110_temporal_indicator_committed_state,fmr_b110_physical_parameters_t','fmr_new_b110_temporal_indicator_committed_state')
 s=replace(s,'''  use mod_soil_temperature_contract,only:soil_temperature_field_view_t,build_soil_temperature_field_view, &
       initialize_soil_temperature_state,SOIL_TEMP_OK
  use mod_fmr_crop_soil_n_thermal_application,only:thermal_crop_soil_states_match,soil_n_thermal_template
''')
 s=replace(s,'reactive_n_joint_states_match,reactive_n_thermal_states_match','reactive_n_joint_states_match')
 s=replace(s,"  character(8),parameter::HEAT_MAGIC='S5NC0003',HEAT_PENDING_MAGIC='S5NC0004'\n")
 s=replace(s,'''    logical::thermal
    type(kernel_parameter_identity_t)::identity
    type(soil_temperature_field_view_t)::heat
''')
 s=replace(s,'''    logical::thermal
    type(kernel_parameter_identity_t)::identity
    real(real64),allocatable::temperatures(:)
    type(kernel_committed_state_t)::certified_water
''')
 s=replace(s,'    thermal=soil_n_thermal_template(template)\n')
 s,n=thermal_false(s)
 if n!=6:raise ValueError('codec thermal branch count '+str(n))
 s=replace(s,'water,coupled,status,heat_parameters)','water,coupled,status)')
 s=replace(s,'    type(fmr_b110_physical_parameters_t),intent(in),optional::heat_parameters\n')
 s=replace(s,'''        thermal=tag==HEAT_MAGIC.or.tag==HEAT_PENDING_MAGIC
        if((tag/=MAGIC.and.tag/=PENDING_MAGIC.and..not.thermal).or. &
          n/=size(p%mineral%dz_cm).or.n<1.or.(mode/=0.and.mode/=1))exit decoding
        if(thermal.neqv.soil_n_thermal_template(template))exit decoding
        if(thermal.and..not.present(heat_parameters))exit decoding''','''        if((tag/=MAGIC.and.tag/=PENDING_MAGIC).or.n/=size(p%mineral%dz_cm).or.n<1.or.(mode/=0.and.mode/=1))exit decoding''')
 return replace(s,'tag==PENDING_MAGIC.or.tag==HEAT_PENDING_MAGIC','tag==PENDING_MAGIC',2)

PROJECTORS={
 'src/runtime/mod_fmr_serialized_reference_backend.f90':project_backend,
 'src/runtime/mod_fmr_b111_reactive_n_joint_application.f90':project_matcher,
 'src/adapter/mod_crop_soil_n_joint_restart_file.f90':project_codec}

def validate(current,baseline):
 if set(current)!=set(PROJECTORS)or set(baseline)!=set(PROJECTORS):raise ValueError('projection surface')
 for path,project in PROJECTORS.items():
  if project(current[path])!=baseline[path]:raise ValueError('default behavior projection changed: '+path)
 return True

def project_moving(s):
 """Remove only the declared eligibility/owner-dispatch additions."""
 s=replace(s,'''# Source/evidence-only owner selection. This is never a full moving PASS.
if [[ "${1:-}" == --nut-thermal-owner-only ]]; then
  python3 -B tests/nut-thermal/verify_thermal_successor.py
  python3 -B tests/crop-co2/verify_co2_successor.py
  echo 'FCI_NUT_THERMAL_OWNER_RECONCILIATION=PASS'
  exit 0
fi
nut_thermal_exact_successor=0
NUT_THERMAL_BACKEND=7e1b034e5cd134050e695c9a097c44a3eaeca344
\n''')
 s=replace(s,'''if [[ -f integration/audits/MC_NUT01_ACCEPTED_THERMAL_STATUS.json ]]; then
  python3 -B tests/nut-thermal/verify_thermal_successor.py || fail 'unqualified accepted thermal N owner'
  nut_thermal_exact_successor=1
fi
''')
 s=replace(s,'''  if (( nut_thermal_exact_successor )) && [[ "$path" == "$BACKEND" ]]; then
    test "$(git rev-parse "HEAD:$path")" = "$NUT_THERMAL_BACKEND" || fail 'thermal backend default projection drift'
    continue
  fi
''')
 s=replace(s,' || nut_thermal_exact_successor','')
 s=replace(s,'|src/process/mod_soil_n_profile_temperature.f90|src/runtime/mod_fmr_soil_n_accepted_temperature.f90|src/runtime/mod_fmr_crop_soil_n_thermal_application.f90','')
 s=replace(s,'''    if (( nut_thermal_exact_successor )) && [[ "$candidate_path" == "$BACKEND" ]]; then
      test "$(git rev-parse "HEAD:$candidate_path")" = "$NUT_THERMAL_BACKEND" || fail 'thermal backend exact successor drift'
    elif (( mc_heat01_exact_successor ))''','''    if (( mc_heat01_exact_successor ))''')
 s=replace(s,'''      if (( nut_thermal_exact_successor )); then
        test "$(git rev-parse HEAD:$BACKEND)" = "$NUT_THERMAL_BACKEND" || fail 'thermal exact backend drift'
      elif (( mc_heat01_exact_successor )); then''','''      if (( mc_heat01_exact_successor )); then''')
 return replace(s,'''  if (( nut_thermal_exact_successor )); then
    backend_authority="$NUT_THERMAL_BACKEND"
  elif (( mc_heat01_exact_successor )); then''','''  if (( mc_heat01_exact_successor )); then''')
