program test_sw_rib_top01_surface_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_external_top_surface_transfer
  implicit none
  real(real64), parameter :: tol=1.0e-14_real64

  call case_zero
  call case_runoff
  call case_flood
  call case_rain_offsets_flood
  call case_evaporation_supply
  call case_direction_switch
  call case_invalid
  write(*,'(A)') 'SW_RIB_TOP01_C=PASS'

contains
  subroutine req(ok,msg)
    logical,intent(in)::ok
    character(len=*),intent(in)::msg
    if(.not.ok) error stop msg
  end subroutine

  subroutine evaluate(b,x,runots)
    type(external_top_surface_balance_t),intent(in)::b
    real(real64),intent(in)::x,runots
    type(external_top_surface_transfer_t)::r
    call materialize_external_top_surface_transfer(b,r)
    call req(r%status==EXT_TOP_TRANSFER_OK,'status')
    call req(abs(r%ribasim_to_swap_cm-x)<=tol,'x')
    call req(abs(r%residual_external_supply_cm-x)<=tol,'residual supply')
    call req(abs(r%composed_legacy_runots_cm-runots)<=tol,'runots')
    call req(abs(r%closure_residual_cm)<=tol,'closure')
  end subroutine

  subroutine case_zero
    type(external_top_surface_balance_t)::b
    b%atmospheric_source_cm=0.20_real64
    b%soil_entry_cm=0.20_real64
    call evaluate(b,0.0_real64,0.0_real64)
  end subroutine

  subroutine case_runoff
    type(external_top_surface_balance_t)::b
    b%atmospheric_source_cm=0.30_real64
    b%soil_entry_cm=0.20_real64
    b%runoff_external_cm=0.10_real64
    call evaluate(b,0.0_real64,0.10_real64)
  end subroutine

  subroutine case_flood
    type(external_top_surface_balance_t)::b
    b%previous_ponding_cm=0.10_real64
    b%candidate_ponding_cm=0.40_real64
    b%soil_entry_cm=0.25_real64
    call evaluate(b,0.55_real64,-0.55_real64)
  end subroutine

  subroutine case_rain_offsets_flood
    type(external_top_surface_balance_t)::b
    b%previous_ponding_cm=0.10_real64
    b%candidate_ponding_cm=0.40_real64
    b%atmospheric_source_cm=0.20_real64
    b%soil_entry_cm=0.25_real64
    call evaluate(b,0.35_real64,-0.35_real64)
  end subroutine

  subroutine case_evaporation_supply
    type(external_top_surface_balance_t)::b
    b%previous_ponding_cm=0.40_real64
    b%candidate_ponding_cm=0.40_real64
    b%evaporation_cm=0.08_real64
    b%soil_entry_cm=0.12_real64
    call evaluate(b,0.20_real64,-0.20_real64)
  end subroutine

  subroutine case_direction_switch
    type(external_top_surface_balance_t)::b
    b%previous_ponding_cm=0.10_real64
    b%candidate_ponding_cm=0.10_real64
    b%soil_entry_cm=0.10_real64
    b%atmospheric_source_cm=0.05_real64
    call evaluate(b,0.05_real64,-0.05_real64)
    b%atmospheric_source_cm=0.10_real64
    call evaluate(b,0.0_real64,0.0_real64)
    b%atmospheric_source_cm=0.15_real64
    call evaluate(b,-0.05_real64,0.05_real64)
  end subroutine

  subroutine case_invalid
    type(external_top_surface_balance_t)::b
    type(external_top_surface_transfer_t)::r
    b%runoff_external_cm=-0.01_real64
    call materialize_external_top_surface_transfer(b,r)
    call req(r%status==EXT_TOP_TRANSFER_INVALID,'negative runoff rejected')
  end subroutine
end program
