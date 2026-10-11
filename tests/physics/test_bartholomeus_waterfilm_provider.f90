program test_bartholomeus_waterfilm_provider
 use iso_fortran_env,only:real64
 use mod_bartholomeus_runtime_input
 use mod_bartholomeus_parameter_contract
 use mod_bartholomeus_waterfilm_provider
 implicit none
 type(bartholomeus_runtime_view_t)::v
 type(BartholomeusImmutableDataset)::d
 real(real64),allocatable::wf(:)
 integer::s
 v%rooted_nodes=1;allocate(v%pressure_head_cm(1),v%water_content(1),v%soil_temperature_k(1))
 v%pressure_head_cm=-100.0_real64;v%water_content=.30_real64;v%soil_temperature_k=293.15_real64
 allocate(d%soil(1))
 d%soil(1)%waterfilm_capac_term=1e-4_real64;d%soil(1)%waterfilm_n_minus_1=.5_real64
 d%soil(1)%waterfilm_m_plus_1=1.5_real64;d%soil(1)%waterfilm_alpha_per_pa=1e-4_real64;d%soil(1)%waterfilm_gen_n=1.5_real64
 call evaluate_bartholomeus_waterfilm(v,d,BARTHOLOMEUS_WATERFILM_REFERENCE,wf,s)
 if(s/=BARTHOLOMEUS_WATERFILM_OK) error stop 1
 if(size(wf)/=1 .or. wf(1)<0) error stop 2
 call evaluate_bartholomeus_waterfilm(v,d,BARTHOLOMEUS_WATERFILM_PRACTICAL,wf,s)
 if(s/=BARTHOLOMEUS_WATERFILM_MODE_NOT_ADMITTED) error stop 3
 print '(a)','PPA_WU05C3P_WATERFILM_PROVIDER=PASS'
end program
