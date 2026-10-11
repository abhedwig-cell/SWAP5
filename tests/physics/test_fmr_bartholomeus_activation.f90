program test_fmr_bartholomeus_activation
 use mod_fmr_bartholomeus_activation
 implicit none
 type(fmr_bartholomeus_selection_t)::c
 integer::r,w
 call select_fmr_bartholomeus_route(c,r,w)
 if(r/=FMR_BARTHOLOMEUS_DISABLED) error stop 1
 c%oxygen_mode=FMR_OXYGEN_BARTHOLOMEUS;c%oxygen_type=FMR_OXYGEN_TYPE_BARTHOLOMEUS
 c%hydraulic_waterfilm_mode=FMR_HYDRAULICS_ANALYTICAL_MVG
 call select_fmr_bartholomeus_route(c,r,w)
 if(r/=FMR_BARTHOLOMEUS_ACTIVE) error stop 2
 c%hydraulic_waterfilm_mode=1
 call select_fmr_bartholomeus_route(c,r,w)
 if(r/=FMR_BARTHOLOMEUS_UNSUPPORTED) error stop 3
 c%oxygen_mode=1
 call select_fmr_bartholomeus_route(c,r,w)
 if(r/=FMR_BARTHOLOMEUS_UNSUPPORTED) error stop 4
 print '(a)','PPA_WU05C3P_ACTIVATION=PASS'
end program
