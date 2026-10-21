! Frozen explicit-conductivity, prescribed-bottom, dry-MvG fixture only.
program precision_replay
 use iso_fortran_env, only: real64
 use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t,b110_default_mvg_provider_t, &
   bind_b110_default_mvg_provider
 use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_WATER_CONTENT
 implicit none
 integer, parameter :: n=32
 type(b110_default_mvg_parameters_t), target :: parameters
 type(b110_default_mvg_provider_t) :: provider
 real(real64) :: a(23,n),meta(9),h(n),best_h(n),r(n),inc(n),baseline(n),total,best,best_r(n),best_inc(n)
 real(real64) :: theta(n),unused_k(n),unused_c(n),unused_dk(n),coefficient,head_ratio
 integer :: u,i,j,index,node,direction,swkimpl,swbotb,selected,accepted
 logical :: ftoph,valid
 character(4096) :: path,line
 call get_command_argument(1,path)
 open(newunit=u,file=trim(path)//'/iterate.csv',status='old')
 read(u,'(A)')line
 do i=1,n
  read(u,*)index,a(:,i)
  if(index/=i)error stop 'iterate ordering'
 enddo
 close(u)
 open(newunit=u,file=trim(path)//'/solve.csv',status='old')
 read(u,'(A)')line
 read(u,*)meta,ftoph,swkimpl,swbotb
 close(u)
 if(swkimpl/=0.or.swbotb/=2.or.int(meta(9))/=n)error stop 'replay scope'
 parameters%active_nodes=n
 allocate(parameters%cofgen(42,n))
 open(newunit=u,file=trim(path)//'/coefficients.csv',status='old')
 read(u,'(A)')line
 do i=1,n
  do j=1,42
   read(u,*)index,node,coefficient
   if(index/=i.or.node/=j)error stop 'coefficient ordering'
   parameters%cofgen(j,i)=coefficient
  enddo
 enddo
 close(u)
 call bind_b110_default_mvg_provider(provider,parameters,meta(1))
 h=a(1,:)
 call evaluate(h,r,inc)
 if(any(r/=a(23,:)).or.any(inc/=a(5,:)))error stop 'native residual replay differs'
 baseline=r
 best=huge(1d0)
 accepted=0
 selected=0
 open(newunit=u,file='candidates.csv',status='new')
 write(u,'(A)')'node,direction,total_residual,max_residual,head_increment_ratio,valid'
 ! Keep surface head, surface flux and prescribed bottom unchanged. Internal faces
 ! are recomputed with captured explicit conductivity and actual provider storage.
 do node=2,n-1
  do direction=-1,1,2
   h=a(1,:)
   h(node)=nearest(h(node),real(direction,real64))
   call evaluate(h,r,inc)
   total=sum(r)
   head_ratio=maxval(abs(h-a(1,:))/max(1d0,abs(a(1,:))))/1d-12
   valid=maxval(abs(r))<=meta(5).and.abs(total)<=meta(6).and.head_ratio<=1
   write(u,'(I0,",",I0,3(",",ES25.17E3),",",L1)')node,direction,total,maxval(abs(r)),head_ratio,valid
   if(valid)then
    accepted=accepted+1
    if(abs(total)<best)then
     selected=node
     best=abs(total)
     best_h=h;best_r=r;best_inc=inc
    endif
   endif
  enddo
 enddo
 close(u)
 if(accepted==0)error stop 'no feasible one-ULP neighbour'
 open(newunit=u,file='best.csv',status='new')
 write(u,'(A)')'node,head,increment,residual,baseline_residual'
 do i=1,n
  write(u,'(I0,4(",",ES25.17E3))')i,best_h(i),best_inc(i),best_r(i),baseline(i)
 enddo
 close(u)
 write(*,'(A,I0)')'FEASIBLE_NEIGHBOURS=',accepted
 write(*,'(A,I0)')'BEST_CHANGED_NODE=',selected
 write(*,'(A,ES25.17E3)')'BASELINE_TOTAL=',sum(baseline)
 write(*,'(A,ES25.17E3)')'BEST_TOTAL=',sum(best_r)
 write(*,'(A)')'FROZEN_NATIVE_RESIDUAL_AND_INCREMENT_EXACT=PASS'
contains
 subroutine evaluate(head,residual,increment)
  real(real64),intent(in)::head(n)
  real(real64),intent(out)::residual(n),increment(n)
  real(real64)::gradient(n+1)
  integer::k
  call provider%evaluate_demand(head,CONSTITUTIVE_DEMAND_WATER_CONTENT,theta,unused_k,unused_c,unused_dk)
  call provider%evaluate_water_content_increment(head,a(2,:),theta,a(4,:),increment)
  gradient(1)=(meta(4)-head(1))/a(15,1)+1d0
  do k=2,n
   gradient(k)=(head(k-1)-head(k))/a(15,k)+1d0
  enddo
  residual(1)=increment(1)*a(7,1)*a(6,1)/meta(1)+a(8,1)-a(9,1)+a(10,1)+a(12,1)*gradient(2)
  if(ftoph)then
   residual(1)=residual(1)-a(11,1)*gradient(1)
  else
   residual(1)=residual(1)+meta(2)
  endif
  do k=2,n-1
   residual(k)=increment(k)*a(7,k)*a(6,k)/meta(1)+a(8,k)-a(9,k)+a(10,k)-a(11,k)*gradient(k)+a(12,k)*gradient(k+1)
  enddo
  residual(n)=increment(n)*a(7,n)*a(6,n)/meta(1)-a(11,n)*gradient(n)+a(8,n)-a(9,n)+a(10,n)
  residual(n)=residual(n)-meta(3)
 end subroutine
end program
