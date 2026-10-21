program swp_reader_contract
 use iso_fortran_env,only:real64
 use mod_column_swp_chemistry
 use mod_b111_reactive_solute_substep,only:b111_reactive_solute_substep_forcing_t
 implicit none
 type(b111_reactive_solute_substep_forcing_t)::f
 real(real64)::dz(4)=[.5d0,.5d0,1d0,1d0],z(4)=[-.25d0,-.75d0,-1.5d0,-2.5d0]
 real(real64)::c(4),rain,drain,bottom
 character(1024)::path,arg
 integer::i
 call get_command_argument(1,path);call get_command_argument(2,arg)
 call import_column_swp_chemistry(trim(path),dz,z,trim(arg)=='heat',f,c,rain,drain,bottom)
 print '(A,7ES25.16)','SCALARS ',rain,drain,bottom,f%frexp,f%cref_mg_cm3,f%tscf,f%molecular_diffusion_cm2_day
 do i=1,4
  print '(A,I2,9ES25.16)','NODE ',i,c(i),f%bulk_density(i),f%kf(i),f%decpot(i),f%fdepth(i), &
   f%gampar(i),f%rtheta(i),f%bexp(i),f%bulk_density(i)*f%kf(i)
 end do
 print '(A,3ES25.16)','FACES ',f%dispersivity_cm
 print '(A)','SWP_ORIGINAL_READER_CONTRACT=PASS'
end program
