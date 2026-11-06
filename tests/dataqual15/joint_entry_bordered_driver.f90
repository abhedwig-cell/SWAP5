program joint_entry_bordered_driver
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_reference_bordered_solver,only:reference_bordered_solve
 implicit none
 integer,parameter::n=112,k=2
 real(real64)::a(n),b(n),c(n),rhs(n),u(n,2),v(n,2),border(n,k),test(n,k),corner(k,k),crhs(k)
 real(real64)::wanted(n),fraction(k),head(n),contact(k),work(n),nan
 integer::i,status,cost,mode
 do i=1,n
  a(i)=-.03d0;c(i)=-.04d0;b(i)=2d0+.01d0*i
  wanted(i)=sin(real(i,real64))*.001d0
  u(i,1)=.002d0*i/n;u(i,2)=.003d0
  v(i,1)=.001d0;v(i,2)=.001d0*(n-i)/n
 end do
 a(1)=0d0;c(n)=0d0;fraction=[.431d0,.7d0]
 border=0d0;test=0d0;corner=0d0
 border(45,1)=-.040803045269828052d0;border(72,2)=-.031d0
 test(45,1)=1d0;test(72,2)=1d0
 do mode=0,1
  corner=0d0
  if(mode==1)then
   corner(1,2)=.01d0;corner(2,1)=-.02d0
  end if
  rhs=b*wanted+matmul(u,matmul(transpose(v),wanted))+matmul(border,fraction)
  do i=2,n
   rhs(i)=rhs(i)+a(i)*wanted(i-1);rhs(i-1)=rhs(i-1)+c(i-1)*wanted(i)
  end do
  crhs=matmul(transpose(test),wanted)+matmul(corner,fraction)
  call reference_bordered_solve(a,b,c,rhs,border,test,corner,crhs,head,contact,status,cost,u,v)
  if(status/=0.or.maxval(abs(head-wanted))>1d-12.or.maxval(abs(contact-fraction))>1d-12) &
   error stop 'coupled complete matrix/contact recovery'
  if(cost/=8)error stop 'complete low-rank solve count'
 end do
 ! A zero-rank border must preserve the original soil-matrix solve.
 work=b*wanted
 do i=2,n
  work(i)=work(i)+a(i)*wanted(i-1);work(i-1)=work(i-1)+c(i-1)*wanted(i)
 end do
 call reference_bordered_solve(a,b,c,work,border(:,:0),test(:,:0),corner(:0,:0),crhs(:0), &
                              head,contact(:0),status,cost)
 if(status/=0.or.maxval(abs(head-wanted))>1d-12.or.cost/=0)error stop 'ordinary rank-zero preservation'
 ! Incomplete/singular constraint blocks never publish a partial head solve.
 test=0d0;corner=0d0
 call reference_bordered_solve(a,b,c,rhs,border,test,corner,crhs,head,contact,status,cost,u,v)
 if(status==0.or.any(head/=0d0).or.any(contact/=0d0))error stop 'singular constraint accepted'
 nan=ieee_value(0d0,ieee_quiet_nan);border(45,1)=nan
 call reference_bordered_solve(a,b,c,rhs,border,test,corner,crhs,head,contact,status,cost)
 if(status==0.or.any(head/=0d0).or.any(contact/=0d0))error stop 'nonfinite border accepted'
 border=0d0
 call reference_bordered_solve(a,b,c,rhs,border,test,corner,crhs,head,contact,status,cost,left=u)
 if(status==0.or.any(head/=0d0).or.any(contact/=0d0))error stop 'missing storage factor accepted'
 print '(a)','COMPLETE_LOW_RANK_BORDER_AND_REFUSALS_PASS'
end program
