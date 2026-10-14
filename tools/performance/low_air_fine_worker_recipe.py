"""Explicit driver workspace reuse; every original physical call remains.

Fine calls use an exact copy of the owning execution body with a caller-owned
backend dummy instead of a newly constructed local backend. Fresh-worker replay,
restart and all other calls retain the original routine byte for byte.
"""
def reuse_fine_workspace(text, *, horizon="1.e-4_real64", fine_steps=65536):
 start=text.index('  subroutine execute_case(')
 end=text.index('  end subroutine execute_case',start)+len('  end subroutine execute_case')
 original=text[start:end]
 workspace=original.replace('subroutine execute_case','subroutine execute_case_workspace')
 old='                          start_time, initial_physical_state, frost_surface_temperature, drain_case, resumed, captured)'
 if workspace.count(old)!=1:raise ValueError('owning signature drift')
 workspace=workspace.replace(old,old[:-1]+', workspace)')
 old='    type(fmr_serialized_reference_backend_t) :: backend'
 if workspace.count(old)!=1:raise ValueError('owning backend declaration drift')
 workspace=workspace.replace(old,'    type(fmr_serialized_reference_backend_t),target,intent(inout) :: workspace')
 workspace=workspace.replace('call backend%initialize(top)','call workspace%initialize(top)').replace('fmr_execute_serialized_resolved_physical_column(backend,','fmr_execute_serialized_resolved_physical_column(workspace,').replace('observation = backend%observation()','observation = workspace%observation()')
 if 'backend%'in workspace or '(backend,'in workspace:raise ValueError('unrecognized backend access')
 # No original computation or assertion is edited in the fresh routine.
 text=text[:end]+'\n\n'+workspace+text[end:]
 def change(old,new):
  nonlocal text
  if text.count(old)!=1:raise ValueError('owning fine recipe drift: '+old[:60])
  text=text.replace(old,new)
 change(f'      direct=initial;dt={horizon}/{fine_steps}._real64;fine_exchange=0._real64',
        f'      block\n      type(fmr_serialized_reference_backend_t),target :: fine_workspace\n      direct=initial;dt={horizon}/{fine_steps}._real64;fine_exchange=0._real64')
 change('        call execute_case(2,0._real64,q,-999999._real64,dt,.false.,.true.,again,observation, &',
        '        call execute_case_workspace(2,0._real64,q,-999999._real64,dt,.false.,.true.,again,observation, &')
 change('             start_time=real(i-1,real64)*dt,drain_case=.true.)',
        '             start_time=real(i-1,real64)*dt,drain_case=.true.,workspace=fine_workspace)')
 change('        direct=next\n      end do\n      call copy_soil_temperature_profile',
        '        direct=next\n      end do\n      end block\n      call copy_soil_temperature_profile')
 if text[text.index('  subroutine execute_case('):text.index('  end subroutine execute_case')+len('  end subroutine execute_case')]!=original:raise ValueError('original fresh worker mutated')
 return text
