program test_perf01_prepared_increment
  use iso_fortran_env,only:real64,int64
  use mod_b110_default_mvg_provider
  implicit none
  integer,parameter::nn=32
  type(b110_default_mvg_parameters_t),target::p
  type(b110_default_mvg_provider_t)::original
  type(b110_prepared_increment_provider_t)::prepared
  real(real64)::c(24,nn),old(nn),new(nn),theta(nn),thetaold(nn),k(nn),cap(nn),dk(nn),a(nn),b(nn),elastic(nn)
  integer::i,j,mode,count
  c=0.0_real64
  c(1,:)=.032_real64;c(2,:)=.423_real64;c(3,:)=4.75_real64
  c(4,:)=.0135_real64;c(5,:)=.365_real64;c(6,:)=1.455_real64
  c(7,:)=1.0_real64-1.0_real64/c(6,:);c(8,:)=c(4,:)
  c(10,:)=c(3,:);c(11,:)=.999_real64;c(12,:)=.99_real64*c(3,:)
  c(22,:)=-1.e6_real64;c(23,:)=1.e-12_real64;elastic=1.e-5_real64
  count=0
  do mode=1,3
    if(mode==2)c(9,:)=-2.0_real64
    if(mode==3)c(9,:)=0.0_real64
    if(mode==3)then
      call initialize_b110_default_mvg_parameters(p,c,enable_elastic_storage=.true.,specific_elastic_storage_input=elastic)
    else
      call initialize_b110_default_mvg_parameters(p,c)
    end if
    call bind_b110_default_mvg_provider(original,p,.005_real64)
    do j=1,300
      do i=1,nn
        old(i)=-10.0_real64**(-3.0_real64+9.0_real64*real(i-1,real64)/real(nn-1,real64))
        if(mod(i,8)==0)old(i)=.1_real64
        new(i)=old(i)*(1.0_real64+.5_real64*sin(real(i*j,real64)))
        if(mod(j,5)==0)new(i)=old(i)
        if(mod(j,7)==0)new(i)=-old(i)
      end do
      call prepare_b110_increment_origin(prepared,original,old)
      ! Reused workspace with changed origins must fall back to the original.
      if(mod(j,3)==0)old=old*1.01_real64
      call original%evaluate(old,thetaold,k,cap,dk)
      call original%evaluate(new,theta,k,cap,dk)
      call original%evaluate_water_content_increment(new,old,theta,thetaold,a)
      call prepared%evaluate_water_content_increment(new,old,theta,thetaold,b)
      if(any(transfer(a,[0_int64],nn)/=transfer(b,[0_int64],nn)))error stop 'prepared increment bit drift'
      count=count+nn
    end do
  end do
  print '(A,I0)','PERF01_PREPARED_EXACT_PAIRS=',count
  print '(A)','PERF01_PREPARED_INCREMENT=PASS'
end program
