program actual_original_saturation_derivative
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  use MOD_arrays,only:mcof
  use MOD_grid,only:numnod,numlay,layer
  use MOD_swap_base,only:swfrost,swmacro,swhyst
  use variables,only:indeks,fhyst,fluseksatexm,dt
  use MOD_MvG,only:cofgen,set_cofgen_pointers,watcon,moiscap,hconduc,dhconduc, &
    swsophy,iHWCKmodel,sw_use_elas,fl_use_tables,fl_use_kh_power
  implicit none
  real(8)::clock,node,recorded_head,recorded_capacity,head,water,capacity,derivative,left,right,heads(6)
  integer::unit,i,nonfinite,incorrect
  character(1024)::path,mode
  call get_command_argument(1,path);call get_command_argument(2,mode)
  numnod=1;numlay=1;layer(1)=1;swfrost=0;swmacro=0;swhyst=0
  swsophy=0;iHWCKmodel=1;sw_use_elas=0;fl_use_tables=.false.;fl_use_kh_power=.false.
  indeks=-1;fhyst=1d0;fluseksatexm=.false.;cofgen=0d0
  open(newunit=unit,file=trim(path),status='old',action='read')
  read(unit,*)clock,dt,node,recorded_head,recorded_capacity,cofgen(:,1)
  close(unit)
  call set_cofgen_pointers
  heads=[recorded_head,-1d-12,-1d-9,-1d-6,-1d-3,1d0]
  nonfinite=0;incorrect=0
  do i=1,size(heads)
    head=heads(i);water=watcon(1,head);capacity=moiscap(1,head)
    derivative=dhconduc(1,head,water,capacity,1d0)
    left=hconduc(1,head-1d-6,watcon(1,head-1d-6),1d0)
    right=hconduc(1,head+1d-6,watcon(1,head+1d-6),1d0)
    if(.not.all(ieee_is_finite([water,capacity,left,right])))error stop 'Nonfinite original physical plateau'
    if(left/=right.or.left/=cofgen(3,1))error stop 'Actual original conductivity is not constant in tested domain'
    if(.not.ieee_is_finite(derivative))nonfinite=nonfinite+1
    if(derivative/=0d0)incorrect=incorrect+1
    if(trim(mode)=='corrected'.and.(.not.ieee_is_finite(derivative).or.derivative/=0d0)) &
      error stop 'Actual original constant conductivity derivative is inconsistent'
    write(*,'(a,1x,i0,*(1x,es25.17e3))')'ACTUAL_ORIGINAL_SATURATION_DERIVATIVE',i,head,water,capacity,derivative,left,right
  end do
  if(trim(mode)=='original')then
    if(nonfinite<1.or.incorrect<1)error stop 'Actual original plateau derivative defect not reproduced'
    write(*,'(a,2(1x,i0))')'REAL_ORIGINAL_SATURATION_DERIVATIVE_DEFECT_REPRODUCED',nonfinite,incorrect
  else if(trim(mode)=='corrected')then
    write(*,'(a)')'REAL_ORIGINAL_SATURATION_DERIVATIVE_CORRECTION_PASS'
  else
    error stop 'Foreign original saturation derivative mode'
  end if
end program
