program macro_native_thermal_driver
 use iso_fortran_env,only:real64
 use mod_macro_liquid_thermal
 implicit none
 type(macro_liquid_thermal_result_t)::r,refused
 real(real64),allocatable::w0(:,:),w1(:,:),q(:,:),x(:,:),sink(:,:),temperature(:,:),tm0(:),tm1(:),top0(:),top1(:),bottom(:)
 logical,allocatable::initial(:,:),ma(:),ta(:),ba(:)
 real(real64)::t0,t1,ql,qr,external,total_matrix,stock,residual,departure,convergence(4),last_matrix
 integer::ninterval,nd,n,unit,kind,interval,id,node,steps,step_counts(4),u,thermal_unit,missing_top,missing_matrix
 character(2048)::path
 character(80)::filename
 call get_command_argument(1,path)
 step_counts=[1,4,16,64];last_matrix=huge(1d0)
 do kind=1,4
  steps=step_counts(kind);open(newunit=unit,file=trim(path),status='old');read(unit,*)ninterval,nd,n
  if(kind==1)then
   allocate(w0(nd,n),w1(nd,n),q(nd,n+1),x(nd,n),sink(nd,n),temperature(nd,n),tm0(n),tm1(n),top0(nd),top1(nd),bottom(nd),initial(nd,n),ma(n),ta(nd),ba(nd))
  end if
  initial=.true.;ma=.true.;ta=.true.;ba=.false.;bottom=0d0
  external=0d0;total_matrix=0d0;stock=0d0;residual=0d0;departure=0d0;missing_top=0;missing_matrix=0
  write(filename,'(a,i0,a)')'macro-ledger-',steps,'.csv';open(newunit=u,file=trim(filename),status='replace')
  if(kind==4)open(newunit=thermal_unit,file='macro-temperature.csv',status='replace')
  do interval=1,ninterval
   read(unit,*)t0,t1
   do node=1,n;read(unit,*)tm0(node),tm1(node);end do
   do id=1,nd
    read(unit,*)top0(id),top1(id)
    do node=1,n
     read(unit,*)w0(id,node),w1(id,node),ql,qr,x(id,node),sink(id,node)
     if(node>1)then
      if(q(id,node)/=ql)error stop 'input face mismatch'
     end if
     q(id,node)=ql;q(id,node+1)=qr
    end do
   end do
   if(interval==1)then
    do id=1,nd;temperature(id,:)=tm0;end do
   end if
   ! Refusals are tested on the actual first affected interval, not dummy zero flux.
   if(any(q(:,1)>0d0).and.missing_top==0)then
    ta=.false.
    call advance_macro_liquid_thermal(w0,w1,q,x,sink,temperature,initial,tm0,tm1,ma,top0,top1,ta,bottom,bottom,ba,t1-t0,steps,4.18d0,refused)
    if(refused%produced)error stop 'accepted actual missing rain donor'
    ta=.true.;missing_top=1
   end if
   if(any(x<0d0).and.missing_matrix==0)then
    ma=.false.
    call advance_macro_liquid_thermal(w0,w1,q,x,sink,temperature,initial,tm0,tm1,ma,top0,top1,ta,bottom,bottom,ba,t1-t0,steps,4.18d0,refused)
    if(refused%produced)error stop 'accepted actual missing matrix donor'
    ma=.true.;missing_matrix=1
   end if
   call advance_macro_liquid_thermal(w0,w1,q,x,sink,temperature,initial,tm0,tm1,ma,top0,top1,ta,bottom,bottom,ba,t1-t0,steps,4.18d0,r)
   if(.not.r%produced)then
    write(*,*)'REFUSED_ACTUAL_INTERVAL',interval,t0,t1
    error stop 'actual explicit-donor replay'
   end if
   temperature=r%temperature_c
   external=external+r%external_net_into_j_cm2;total_matrix=total_matrix+sum(r%matrix_energy_j_cm2);stock=stock+r%stock_change_j_cm2
   residual=max(residual,abs(r%residual_j_cm2))
   do id=1,nd
    do node=1,n
     if(w1(id,node)>0d0)departure=max(departure,abs(temperature(id,node)-tm1(node)))
     if(kind==4)write(thermal_unit,'(2(es25.17e3,a),2(i0,a),2(es25.17e3,a),l1)')t0,',',t1,',',id,',',node,',',temperature(id,node),',',r%matrix_energy_j_cm2(id,node),',',r%temperature_available(id,node)
    end do
   end do
   write(u,'(7(es25.17e3,a))')t0,',',t1,',',r%stock_change_j_cm2,',',r%external_net_into_j_cm2,',',sum(r%matrix_energy_j_cm2),',',r%residual_j_cm2,',',departure,','
  end do
  close(unit);close(u);if(kind==4)close(thermal_unit)
  if(missing_top/=1.or.missing_matrix/=1)error stop 'actual nonzero donor controls not exercised'
  if(abs(stock+total_matrix-external)>1d-9)error stop 'full replay liquid energy budget'
  convergence(kind)=total_matrix
  write(*,'(a,i0,5(a,es25.17e3))')'REPLAY',steps,',STOCK=',stock,',EXTERNAL=',external,',MATRIX=',total_matrix,',MAX_RESIDUAL=',residual,',DEPARTURE=',departure
 end do
 if(abs(convergence(4)-convergence(3))>=abs(convergence(3)-convergence(2)))error stop 'native donor time refinement'
 write(*,'(a)')'EXPLICIT_INITIAL_EQUILIBRIUM_PRESCRIBED_DONORS_LINEAR_MATRIX_PATH_NOT_HISTORICAL_FULL_ENERGY'
end program
