! Call complete original modules. No water retention/conductivity formula is copied.
program actual_original_hydraulic_probe
  use ieee_arithmetic,only:ieee_is_finite
  use MOD_grid,only:numnod,layer
  use MOD_swap_base,only:swfrost,swhyst
  use MOD_MvG,only:cofgen,iHWCKmodel,swsophy,sw_use_elas,fl_use_tables,fl_use_kh_power, &
    set_cofgen_pointers,calc_cofgen_extra,watcon,moiscap,hconduc,dhconduc
  use WC_K_models_04_11,only:BiModal,NoVap
  use variables,only:indeks,fhyst,fluseksatexm
  implicit none
  integer::model,soil,j,ios,samples,unit,actual_models(2),actual_count
  logical::rdinqr
  external::rdinqr,rdinit,rdfdor,rdfinr
  character(len=2048)::argument,actual_input
  real(8)::head,w,capacity,k,dk,left_w,right_w,left_k,right_k,delta,actual_ksatexm(2)
  call get_command_argument(1,argument);read(argument,*)model
  if(model<1.or.model>11)error stop 'Unsupported original component selector'
  numnod=2;layer(1:2)=[1,2];swsophy=0;sw_use_elas=0;swfrost=0;swhyst=0
  fl_use_tables=.false.;fl_use_kh_power=.false.;fluseksatexm=.false.
  indeks=-1;fhyst=1d0;NoVap=.true.;BiModal=any(model==[3,6,7,10,11])
  call set_cofgen_pointers()
  cofgen=0d0
  ! Read the actual two distinct soil rows using the original TTUTIL parser.
  ! No original retention, capacity or conductivity routine is replaced.
  call get_command_argument(3,actual_input)
  if(len_trim(actual_input)==0)error stop 'Missing actual soil input path'
  call rdinit(31,6,trim(actual_input))
  actual_count=2
  call rdfinr('IHWCKMODEL',1,11,actual_models,2,actual_count)
  if(actual_count/=2.or.any(actual_models/=model))error stop 'Foreign actual per-layer hydraulic model'
  if(rdinqr('ELAS').or.rdinqr('h_power').or.rdinqr('SWAP_SOILS_DB')) &
    error stop 'Unselected original constitutive component options'
  call actual_values('ORES',0d0,1d0,1)
  call actual_values('OSAT',0d0,1d0,2)
  call actual_values('KSATFIT',1d-5,1d5,3)
  call actual_values('ALFA',1d-4,100d0,4)
  call actual_values('LEXP',-25d0,50d0,5)
  call actual_values('NPAR',1.001d0,9d0,6)
  cofgen(7,1:2)=1d0-1d0/cofgen(6,1:2)
  cofgen(8,1:2)=cofgen(4,1:2)
  call actual_values('H_ENPR',-40d0,0d0,9)
  cofgen(10,1:2)=-999d0
  call rdfdor('KSATEXM',1d-5,1d5,actual_ksatexm,2,actual_count)
  if(any(actual_ksatexm>cofgen(3,1:2)))error stop 'Unselected measured Ksat interpolation'
  call actual_values('ALFA_2',1d-4,100d0,13)
  call actual_values('NPAR_2',1.001d0,9d0,14)
  cofgen(15,1:2)=1d0-1d0/cofgen(14,1:2)
  call actual_values('OMEGA_1',1d-4,.9999d0,16)
  cofgen(17,1:2)=1d0-cofgen(16,1:2)
  if(model==7.or.model==11)then
    call actual_values('H0',-5d7,-1d5,18)
    cofgen(18,1:2)=-cofgen(18,1:2)
  end if
  if(model==11)then
    call actual_values('HA',-1d5,0d0,19);cofgen(19,1:2)=-cofgen(19,1:2)
    call actual_values('APAR',-5d0,0d0,20)
    call actual_values('OMEGA_K',1d-8,.1d0,21)
    call rdfinr('SWVAPOR',0,1,actual_models,2,actual_count)
    if(actual_count/=2.or.any(actual_models/=0))error stop 'Unselected active vapor reference'
  end if
  close(31,iostat=ios)
  do soil=1,2
    write(*,'(a,1x,i0,21(1x,es25.17e3))')'ACTUAL_ORIGINAL_TTUTIL_SOIL_PARAMETERS',soil,cofgen(1:21,soil)
  end do
  iHWCKmodel=model
  call calc_cofgen_extra(2)
  call get_command_argument(2,argument)
  open(newunit=unit,file=trim(argument),status='old',action='read')
  read(unit,*)samples
  if(samples<1.or.samples>100000)error stop 'Invalid sampled original pressure count'
  do j=1,samples
    read(unit,*)head
    if(.not.ieee_is_finite(head).or.head>=0d0)error stop 'Invalid actual sampled original pressure'
    do soil=1,2
      delta=abs(head)*1d-5
      w=watcon(soil,head);capacity=moiscap(soil,head)
      k=hconduc(soil,head,w,1d0);dk=dhconduc(soil,head,w,capacity,1d0)
      left_w=watcon(soil,head-delta);right_w=watcon(soil,head+delta)
      left_k=hconduc(soil,head-delta,left_w,1d0);right_k=hconduc(soil,head+delta,right_w,1d0)
      if(.not.all(ieee_is_finite([w,capacity,k,dk,left_w,right_w,left_k,right_k]))) &
        error stop 'Nonfinite actual original constitutive result'
      write(*,'(a,3(1x,i0),10(1x,es25.17e3))')'ACTUAL_ORIGINAL_HYDRAULIC_SAMPLE', &
        model,soil,j,head,w,capacity,k,dk,left_w,right_w,left_k,right_k,delta
    end do
  end do
  read(unit,*,iostat=ios)head
  if(ios>=0)error stop 'Extra actual sampled original pressure data'
  close(unit)
contains
  subroutine actual_values(name,low,high,index)
    character(len=*),intent(in)::name
    real(8),intent(in)::low,high
    integer,intent(in)::index
    real(8)::values(2)
    integer::count
    count=2
    call rdfdor(name,low,high,values,2,count)
    if(count/=2.or..not.all(ieee_is_finite(values)))error stop 'Invalid actual original soil array'
    cofgen(index,1:2)=values
  end subroutine
end program
