 subroutine make_file_calendar(items,plan,code)
  type(soil_n_material_input_t),intent(in)::items(2)
  type(soil_n_amendment_calendar_t),intent(out)::plan
  integer,intent(out)::code
  integer::unit,j,day,error_line
  character(10)::date
  type(b111_soil_n_material_t)::m
  open(newunit=unit,file='explicit-amendment-tables.snm',status='replace',action='write')
  write(unit,'(A)')'MatNum MatName AppAge OrgMatFrac OrgNFrac NH4NFrac NO3NFrac'
  do j=1,2
   m=items(j)%material
   write(unit,'(I1,A,5(1X,ES26.17E3))')j," 'Material'",m%application_age,m%organic_matter_fraction, &
     m%organic_n_fraction,m%ammonium_n_fraction,m%nitrate_n_fraction
  end do
  write(unit,'(A)')'smedate iMat Dosagekgha VolatFraction'
  do day=1,2
   write(date,'(A,I2.2)')'1900-01-',day
   do j=1,2
    write(unit,'(A,1X,I1,2(1X,ES26.17E3))')date,j,1d4*items(j)%material%application_kg_m2, &
      items(j)%material%volatilization_fraction
   end do
  end do
  close(unit)
  call read_soil_n_amendment_tables('explicit-amendment-tables.snm','1900-01-01',plan,code,error_line)
 end subroutine
