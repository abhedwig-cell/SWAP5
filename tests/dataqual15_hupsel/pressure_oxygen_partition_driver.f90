program pressure_oxygen_partition
 use original_micro_attribution,only:original_attribute
 implicit none
 real(8)::x(40,34),dry,oxy,salt,carry
 integer::i,code,n
 do i=1,34
  read(*,*,iostat=code)x(:,i)
  if(code/=0.or.nint(x(10,i))/=i)error stop 'incomplete actual final carrier'
 end do
 n=nint(x(11,1));if(n<1.or.n>34)error stop 'invalid rooted count'
 call original_attribute(n,x(34,:n),x(35,:n),x(36,:n),x(37,:n),x(3,1),x(7,1), &
  nint(x(12,1)),x(26,1),dry,oxy,salt,carry,previous=x(27,1))
 write(*,'(a,4(1x,es25.17e3))')'ATTR',dry,oxy,salt,carry
 if(maxval(abs([dry-x(4,1),oxy-x(5,1),salt-x(6,1),carry-x(28,1)]))>1d-14) &
  error stop 'unchanged original partition bound'
end program
