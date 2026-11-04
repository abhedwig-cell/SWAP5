program matched_oxygen_driver
 use MOD_grid
 use MOD_MvG
 use variables
 use atmosphere_interface
 use plant_interface
 use MOD_cropdevelopment
 use MOD_texture_orgmat
 use MOD_SoilTemperature
 use O2_pars,only:c_top
 implicit none
 real(8)::x(41,34),factor
 integer::i,n,io
 do i=1,34
  read(*,*,iostat=io)x(:,i)
  if(io/=0)error stop 'incomplete actual profile'
  if(nint(x(10,i))/=i)error stop 'node sequence'
  layer(i)=i;h(i)=x(12,i);theta(i)=x(13,i);tsoil(i)=x(14,i)
  wroot_node_top(i)=x(16,i);cofgen(1:7,i)=x(22:28,i)
  dz(i)=x(29,i);orgmat(i)=x(30,i);psand(i)=x(31,i);bdens(i)=x(32,i)
 end do
 n=nint(x(11,1));if(n<1.or.n>34)error stop 'rooted nodes'
 do i=1,34
  if(x(15,i)/=x(15,1).or.x(21,i)/=x(21,1))error stop 'inconsistent shared forcing'
  if(any(x(33:41,i)/=x(33:41,1)))error stop 'inconsistent crop forcing'
 end do
 if(x(38,1)/=.9d0.or.x(39,1)/=.9d0)error stop 'unsupported source shape'
 srl=1d0/x(15,1);tav=x(21,1)
 if(1d0/srl/=x(15,1))error stop 'root length forcing round trip'
 c_mroot=x(33,1);f_senes=x(34,1);q10_root=x(35,1)
 specific_resp_humus=x(36,1);q10_microbial=x(37,1)
 rootradius_m=x(40,1);max_resp_factor=x(41,1)
 if(abs(x(20,1)-672d0/(8.314472d0*(tav+273d0)))>1d-12)error stop 'atmospheric forcing'
 c_top=0d0
 do i=1,n
  call OxygenStress(i,factor)
  write(*,'(i0,3(1x,es25.17e3))')i,factor,x(19,i),abs(factor-x(19,i))
  if(abs(factor-x(19,i))>1d-4)error stop 'unchanged assembled factor bound exceeded'
 end do
end program
