program test_top03_component_receipt
 use, intrinsic::iso_fortran_env,only:real64
 use mod_fmr_surface_water_component_receipt
 implicit none
 type(fmr_surface_water_component_candidate_t)::c
 type(fmr_surface_water_component_receipt_t)::r
 c%valid=.true.;r%valid=.true.
 c%subsurface_swap_to_surface_cm=.3;c%top_swap_to_surface_cm=-.2
 r%subsurface_swap_to_surface_cm=.3;r%top_swap_to_surface_cm=-.2
 call req(surface_water_component_receipt_matches(c,r,1e-12_real64)==FMR_SW_RECEIPT_OK,'exact')
 ! Equal scalar total, wrong components: must fail closed.
 r%subsurface_swap_to_surface_cm=.2;r%top_swap_to_surface_cm=-.1
 call req(abs((c%subsurface_swap_to_surface_cm+c%top_swap_to_surface_cm)-(r%subsurface_swap_to_surface_cm+r%top_swap_to_surface_cm))<1e-14_real64,'same total fixture')
 call req(surface_water_component_receipt_matches(c,r,1e-12_real64)==FMR_SW_RECEIPT_MISMATCH,'component masking')
 r%subsurface_swap_to_surface_cm=.3;r%top_swap_to_surface_cm=-.2+5e-13_real64
 call req(surface_water_component_receipt_matches(c,r,1e-12_real64)==FMR_SW_RECEIPT_OK,'tolerance')
 write(*,'(A)')'SW_RIB_TOP03_COMPONENT_RECEIPT=PASS'
contains
 subroutine req(x,m);logical,intent(in)::x;character(*),intent(in)::m
 if(.not.x)then;write(*,'(A,1X,A)')'TOP03_RECEIPT_FAIL',trim(m);error stop 1;end if
 end subroutine
end program
