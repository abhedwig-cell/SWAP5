program actual_original_interception_partition
  use MOD_meteo,only:graidt,nraidt,aintcdt,implicit_interception_partition_probe
  use MOD_irrigation,only:gird,nird,isua
  implicit none
  real(8)::actual_interception,balance,scale,largest
  integer::i,count
  character(100)::mode,arg
  call get_command_argument(1,mode);call get_command_argument(2,arg);read(arg,*)actual_interception
  largest=0d0;count=0
  do i=1,7
    isua=0;graidt=0.47d0;gird=0d0;aintcdt=actual_interception
    select case(i)
    case(2);graidt=0.2d0;gird=0.3d0
    case(3);gird=0.1d0;isua=1
    case(4);graidt=0.5d-7;gird=0.5d-7;aintcdt=0.25d-7
    case(5);gird=0.1d0;aintcdt=0d0
    case(6);gird=0.1d0;aintcdt=0.02d0
    case(7);aintcdt=1d-12
    end select
    call implicit_interception_partition_probe()
    balance=graidt+gird-nraidt-nird-aintcdt
    scale=max(graidt+gird,aintcdt,tiny(1d0))
    write(*,'(a,1x,i0,*(1x,es25.17e3))')'ACTUAL_ORIGINAL_INTERCEPTION_PARTITION',i,graidt,gird,aintcdt,nraidt,nird,balance
    if(trim(mode)=='original'.and.(i<=4.or.i==7))then
      if(abs(balance)<=8d0*epsilon(1d0)*scale)error stop 'Original interception loss not reproduced'
      if(abs(balance+aintcdt)>8d0*epsilon(1d0)*scale)error stop 'Different original interception defect'
      count=count+1
    else
      if(abs(balance)>8d0*epsilon(1d0)*scale.or.abs(balance)>1d-10)error stop 'Original exact interception partition does not conserve'
    end if
    largest=max(largest,abs(balance))
  end do
  if(trim(mode)=='original')then
    if(count/=5)error stop 'Original interception cases omitted'
    write(*,'(a,1x,es25.17e3)')'REAL_ORIGINAL_INTERCEPTION_LOSS_REPRODUCED',largest
  else if(trim(mode)=='corrected')then
    write(*,'(a,1x,es25.17e3)')'REAL_ORIGINAL_EXACT_INTERCEPTION_PARTITION_PASS',largest
  else
    error stop 'Foreign actual partition mode'
  end if
end program
