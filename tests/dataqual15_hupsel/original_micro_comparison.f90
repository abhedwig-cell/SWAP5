program original_micro_comparison
 use iso_fortran_env,only:real64
 use mod_root_micro_matric_flux_table
 use mod_root_micro_de_willigen_process
 implicit none
 type(micro_matric_flux_table_t)::tables(34)
 type(micro_de_willigen_parameters_t)::p
 type(micro_de_willigen_result_t)::r
 real(real64)::x(24,34),row(5),m(430),k(430),sat,largest
 integer::i,j,status,mismatches,n,io,u,v,record
 character(4096)::name
 call get_command_argument(1,name);open(newunit=u,file=trim(name),status='old')
 call get_command_argument(2,name);open(newunit=v,file=trim(name),status='old')
 do i=1,34
  do j=1,430
   read(v,*)row
   if(nint(row(1))/=i.or.nint(row(2))/=j)error stop 'original table order'
   m(j)=row(3);k(j)=row(4);sat=row(5)
  end do
  call build_micro_matric_flux_table(k,0d0,sat,tables(i),status)
  if(status/=MICRO_TABLE_OK)error stop 'original table construction'
  call bind_exact_observed_table(tables(i),m,k,0d0,sat,mismatches,largest,status)
  if(status/=MICRO_TABLE_OK)error stop 'original exact table binding'
 end do
 record=0
 do
  read(u,*,iostat=io)x(:,1)
  if(io<0)exit
  if(io/=0)error stop 'original frame'
  do i=2,34
   read(u,*)x(:,i)
  end do
  record=record+1;n=nint(x(4,1))
  do i=1,34
   if(nint(x(3,i))/=i)error stop 'original frame order'
  end do
  p%root_radius_cm=x(6,1);p%root_conductance_cm_per_day=x(7,1)
  p%stem_a0_per_day=x(8,1);p%stem_a1_per_cm=x(9,1);p%half_leaf_pressure_cm=x(10,1)
  p%campbell_exponent=x(11,1);p%pressure_tolerance_cm=x(12,1);p%newton_tolerance_cm=x(13,1)
  p%residual_tolerance_cm_per_day=x(14,1);p%max_iterations=nint(x(15,1))
  p%oxygen_mode=nint(x(16,1));p%reduction_mode=nint(x(17,1))
  call evaluate_micro_de_willigen(p,x(18,:),x(19,:),x(20,:),x(21,:),n,x(5,1),tables,r)
  if(r%status/=MICRO_DW_OK)error stop 'typed original-input refusal'
  write(*,'(i0,7(1x,es25.17e3))')record,x(1,1),x(2,1), &
   maxval(abs(r%root_extraction_sink-x(22,:))),sum(x(22,:)),r%actual_uptake_total, &
   r%root_pressure_cm-x(23,1),r%leaf_pressure_cm-x(24,1)
 end do
 if(record==0)error stop 'empty original MICRO carrier'
end program
