! Read-only original TTUTIL adapter. This does not admit or execute a model.
program inspect_historical
 use iso_fortran_env,only:real64
 implicit none
 character(1024)::path,name
 integer::u,n,mode,types(64),counts(256),i
 integer::selectors(16),nodes,crops,arg_status
 logical::present(16)
 character(1024)::names(16),output
 real(real64)::first,last
 logical::rdinqr
 call get_command_argument(1,path,status=arg_status)
 if(arg_status/=0.or.len_trim(path)==0)error stop 'requires original project path'
 output='capabilities.csv'
 if(command_argument_count()>2)error stop 'usage: inspect project [output]'
 if(command_argument_count()==2)then
  call get_command_argument(2,output,status=arg_status)
  if(arg_status/=0.or.len_trim(output)==0)error stop 'invalid capability output path'
 end if
 call rdinit(74,0,trim(path))
 call rdstim('tstart',first);call rdstim('tend',last)
 do i=1,16
  select case(i)
  case(1);name='swetr'
  case(2);name='swcrop'
  case(3);name='swmacro'
  case(4);name='swsolu'
  case(5);name='swhea'
  case(6);name='swcalt'
  case(7);name='swinco'
  case(8);name='swbotb'
  case(9);name='swbbcfile'
  case(10);name='swdra'
  case(11);name='swrain'
  case(12);name='swredu'
  case(13);name='swfrost'
  case(14);name='swsnow'
  case(15);name='swpondmx'
  case(16);name='swhyst'
  end select
  names(i)=name;present(i)=rdinqr(trim(name))
  if(present(i))then
   call rdsint(trim(name),selectors(i))
  end if
 end do
 call rdinne('ncomp',n)
 if(n<1.or.n>256)error stop 'invalid original grid capacity'
 call rdfint('ncomp',counts,256,n)
 nodes=sum(counts(:n))
 call rdinne('croptype',n)
 if(n<1.or.n>64)error stop 'invalid original crop capacity'
 call rdfint('croptype',types,64,n)
 crops=n
 close(74)
 ! No capability prefix is published when a later original field is invalid.
 open(newunit=u,file=trim(output),status='new',action='write')
 write(u,'(a)')'kind,index,value'
 write(u,'(a,es25.16e3)')'calendar_start,0,',first
 write(u,'(a,es25.16e3)')'calendar_end,0,',last
 do i=1,16
  if(present(i))write(u,'(a,a,i0)')trim(names(i)),',0,',selectors(i)
 end do
 write(u,'(a,i0)')'nodes,0,',nodes
 do i=1,crops
  write(u,'(a,i0,a,i0)')'croptype,',i,',',types(i)
 end do
 close(u)
 print '(a)','SWP_HISTORICAL_INSPECTED'
end program inspect_historical
