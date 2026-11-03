! Real failed Andelst Jacobian/RHS; frozen linear contact experiment only.
program contact_constraint_driver
 use iso_fortran_env,only:real64
 use mod_reference_linear_solver,only:reference_tridag
 implicit none
 integer::n,i,j,k,status,unit
 real(real64)::jump,dt,psi,lambda,denominator,linear_error,contact_error
 real(real64),allocatable::a(:),b(:),c(:),h(:),rhs(:),u(:),v(:),force(:),delta(:),gamma(:)
 character(2048)::path
 call get_command_argument(1,path);open(newunit=unit,file=trim(path),status='old')
 read(unit,*)n,j,k,dt,jump
 if(n/=112.or.j/=26.or.k/=27.or.jump<=0d0.or.dt<=0d0)error stop 'contact fixture identity'
 allocate(a(n),b(n),c(n),h(n),rhs(n),u(n),v(n),force(n),delta(n),gamma(n))
 do i=1,n
  read(unit,*)h(i),rhs(i),a(i),b(i),c(i)
 end do
 close(unit)
 call reference_tridag(n,a,b,c,rhs,u,gamma,status)
 if(status/=0)error stop 'actual Newton solve failed'
 force=0d0;force(j)=jump
 call reference_tridag(n,a,b,c,force,v,gamma,status)
 if(status/=0)error stop 'contact response solve failed'
 ! HeadCalc uses h_new = h - delta; source absorption subtracts from vector_F.
 psi=h(j)+h(k);denominator=v(j)+v(k)
 if(abs(denominator)<tiny(1d0))error stop 'singular contact Schur complement'
 lambda=(u(j)+u(k)-psi)/denominator
 if(lambda<=0d0.or.lambda>=1d0)error stop 'no bounded contact witness'
 delta=u-lambda*v
 linear_error=0d0
 do i=1,n
  contact_error=b(i)*delta(i)-rhs(i)+lambda*force(i)
  if(i>1)contact_error=contact_error+a(i)*delta(i-1)
  if(i<n)contact_error=contact_error+c(i)*delta(i+1)
  linear_error=max(linear_error,abs(contact_error))
 end do
 contact_error=abs(psi-delta(j)-delta(k))
 if(psi-u(j)-u(k)>=0d0)error stop 'off branch topology witness changed'
 if(psi-u(j)-u(k)+denominator<=0d0)error stop 'on branch topology witness changed'
 if(linear_error>1d-15.or.contact_error>1d-15)error stop 'contact linear witness not closed'
 write(*,'(a,6(a,es25.17e3))')'CONTACT',',',lambda,',',lambda*jump,',',lambda*jump*dt, &
  ',',linear_error,',',contact_error,',',maxval(abs(delta))
 do i=1,n
  write(*,'(a,i0,a,es25.17e3)')'DELTA,',i,',',delta(i)
 end do
 print '(a)','ACTUAL_LINEAR_CONTACT_WITNESS_PASS_NONLINEAR_REPAIR_OPEN'
end program
