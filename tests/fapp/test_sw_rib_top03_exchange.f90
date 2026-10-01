program test_sw_rib_top03_exchange
 use, intrinsic::iso_fortran_env,only:real64
 use mod_fmr_top_surface_exchange
 implicit none
 type(fmr_top_surface_exchange_t)::r
 call materialize_fmr_top_surface_exchange(0._real64,0._real64,.3_real64,0._real64,.2_real64,.1_real64,r)
 call req(r%available.and.abs(r%signed_swap_to_external_cm-.1_real64)<1e-14_real64,'runoff')
 call materialize_fmr_top_surface_exchange(.1_real64,.4_real64,0._real64,0._real64,.25_real64,0._real64,r)
 call req(abs(r%signed_swap_to_external_cm+.55_real64)<1e-14_real64,'inundation')
 call materialize_fmr_top_surface_exchange(.1_real64,.4_real64,.2_real64,0._real64,.25_real64,0._real64,r)
 call req(abs(r%signed_swap_to_external_cm+.35_real64)<1e-14_real64,'rain offset')
 call materialize_fmr_top_surface_exchange(.4_real64,.4_real64,0._real64,.08_real64,.12_real64,0._real64,r)
 call req(abs(r%signed_swap_to_external_cm+.2_real64)<1e-14_real64,'evap supply')
 call req(abs(r%closure_residual_cm)<1e-14_real64,'closure')
 write(*,'(A)')'SW_RIB_TOP03_EXCHANGE=PASS'
contains
 subroutine req(x,m)
 logical,intent(in)::x;character(*),intent(in)::m
 if(.not.x)then;write(*,'(A,1X,A)')'SW_RIB_TOP03_FAIL',trim(m);error stop 1;end if
 end subroutine
end program
