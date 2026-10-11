program test_fmr_bartholomeus_execution_preservation
 use iso_fortran_env,only:real64
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_soil_temperature_contract,only:soil_temperature_field_view_t
 use mod_bartholomeus_parameter_contract
 use mod_fmr_bartholomeus_activation
 use mod_fmr_bartholomeus_execution
 use mod_root_water_uptake_process,only:root_water_uptake_flux_result_t
 implicit none
 type(process_hydraulic_view_t)::h
 type(soil_temperature_field_view_t)::t
 type(BartholomeusImmutableDataset)::d
 type(BartholomeusCropParameters)::c
 type(fmr_bartholomeus_selection_t)::cfg
 type(root_water_uptake_flux_result_t)::base,out
 real(real64)::wr(2),wr0(2)
 integer::s
 allocate(base%root_extraction_sink(3));base%root_extraction_sink=[1._real64,2._real64,3._real64];base%actual_uptake_total=6
 wr=1;wr0=1
 call fmr_apply_bartholomeus_to_root_sink(cfg,h,t,d,c,wr,wr0,0._real64,base,out,s)
 if(s/=FMR_BARTHOLOMEUS_EXEC_OK) error stop 1
 if(.not.allocated(out%root_extraction_sink)) error stop 2
 if(any(out%root_extraction_sink/=base%root_extraction_sink)) error stop 3
 if(out%actual_uptake_total/=base%actual_uptake_total) error stop 4
 cfg%oxygen_mode=FMR_OXYGEN_BARTHOLOMEUS;cfg%oxygen_type=FMR_OXYGEN_TYPE_BARTHOLOMEUS;cfg%hydraulic_waterfilm_mode=1
 call fmr_apply_bartholomeus_to_root_sink(cfg,h,t,d,c,wr,wr0,0._real64,base,out,s)
 if(s/=FMR_BARTHOLOMEUS_EXEC_UNSUPPORTED) error stop 5
 print '(a)','PPA_WU05C3A_OXYGEN_OFF_PRESERVATION=PASS'
end program
