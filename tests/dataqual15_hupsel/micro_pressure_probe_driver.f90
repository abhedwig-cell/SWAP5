program micro_pressure_probe_driver
 use iso_fortran_env,only:real64
 use mod_root_micro_matric_flux_table
 use mod_root_micro_de_willigen_process
 implicit none
 type(micro_matric_flux_table_t)::tables(34)
 type(micro_de_willigen_parameters_t)::p
 type(micro_de_willigen_result_t)::r
 real(real64)::x(40,34),row(6),m(430),k(430),dry,sat,largest,dryloss,oxyloss,saltloss,carry
 integer::i,j,n,status,mismatches
 do i=1,34
  read(*,*)x(:,i)
  if(nint(x(10,i))/=i)error stop 'node sequence'
 end do
 n=nint(x(11,1));if(n<1.or.n>34)error stop 'rooted shape'
 do i=1,34
  read(*,*)row
  if(nint(row(3))/=i.or.row(4)/=0d0)error stop 'table endpoint sequence'
  dry=row(5);sat=row(6)
  do j=1,430
   read(*,*)row
   if(nint(row(3))/=i.or.nint(row(4))/=j)error stop 'table sequence'
   m(j)=row(5);k(j)=row(6)
  end do
  call build_micro_matric_flux_table(k,dry,sat,tables(i),status)
  if(status/=MICRO_TABLE_OK)error stop 'public table reconstruction'
  call bind_exact_observed_table(tables(i),m,k,dry,sat,mismatches,largest,status)
  if(status/=MICRO_TABLE_OK)error stop 'exact observed coefficient binding'
  write(*,'(a,2(1x,i0),1x,es25.17e3)')'TABLE',i,mismatches,largest
 end do
 p%root_radius_cm=x(16,1);p%root_conductance_cm_per_day=x(17,1)
 p%stem_a0_per_day=x(18,1);p%stem_a1_per_cm=x(19,1);p%half_leaf_pressure_cm=x(20,1)
 p%campbell_exponent=x(21,1);p%pressure_tolerance_cm=x(22,1);p%newton_tolerance_cm=x(23,1)
 p%residual_tolerance_cm_per_day=x(24,1);p%max_iterations=nint(x(25,1))
 p%oxygen_mode=nint(x(13,1));p%reduction_mode=nint(x(14,1))
 call evaluate_micro_de_willigen(p,x(32,:),x(34,:),x(35,:),x(38,:),n,x(3,1),tables,r)
 write(*,'(a,1x,i0)')'STATUS',r%status
 if(r%status/=MICRO_DW_OK)error stop 'typed MICRO refusal'
 call attribute_micro_root_stress_losses(x(34,:),x(35,:),x(36,:),x(37,:),n,x(3,1), &
  r%actual_uptake_total,nint(x(12,1)),x(26,1),dryloss,oxyloss,saltloss,carry,status,previous_drought_factor=x(27,1))
 if(status/=MICRO_DW_OK)error stop 'stress attribution refusal'
 write(*,'(a,4(1x,es25.17e3))')'HEAD',r%root_pressure_cm,r%leaf_pressure_cm,r%actual_uptake_total,r%reduction_factor
 write(*,'(a,4(1x,es25.17e3))')'ATTR',dryloss,oxyloss,saltloss,carry
 do i=1,34
  write(*,'(a,1x,i0,2(1x,es25.17e3))')'NODE',i,r%root_extraction_sink(i),r%potential_root_sink(i)
 end do
end program
