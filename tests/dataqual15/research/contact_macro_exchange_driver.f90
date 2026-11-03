! A storage stress fixture seeded by the actual contact-witness transfer.
! This is not the archived whole Andelst macropore continuation state.
program contact_macro_exchange_driver
 use iso_fortran_env,only:real64
 use mod_macropore_continuation_state,only:macropore_continuation_state_t
 use mod_macropore_standard_storage,only:macropore_standard_storage_view_t,derive_macropore_standard_storage_view
 implicit none
 type(macropore_continuation_state_t)::state,before
 type(macropore_standard_storage_view_t)::view
 real(real64)::transfer,stock,normalized,residual
 real(real64)::z(4)=[-.5d0,-1.5d0,-2.5d0,-3.5d0],dz(4)=1d0
 logical::ok
 character(128)::argument
 call get_command_argument(1,argument);read(argument,*)transfer
 if(transfer<=0d0.or.transfer>=1d-12)error stop 'expected actual sub-quantum contact transfer'
 call state%initialize(1,4,ok)
 if(.not.ok)error stop 'storage initialize'
 state%icp_bottom_domain=4;state%volume_domain_cp=.1d0
 stock=.1d0-transfer;state%water_domain_cp=0d0;state%water_domain_cp(1,4)=stock
 before=state
 call derive_macropore_standard_storage_view(state,1,z,dz,view)
 if(.not.view%valid.or..not.state%same_values(before))error stop 'storage view invalid or impure'
 normalized=sum(view%normalized_water_cm)
 residual=normalized-.1d0+transfer
 write(*,'(a,4(a,es25.17e3))')'EXCHANGE',',',transfer,',',stock,',',normalized,',',residual
end program
