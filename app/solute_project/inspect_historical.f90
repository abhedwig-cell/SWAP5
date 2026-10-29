! Read-only original TTUTIL adapter. This does not admit or execute a model.
program inspect_historical
 use iso_fortran_env,only:real64
 implicit none
 character(1024)::path,name
 integer::u,n,mode,types(64),counts(256),i
 real(real64)::first,last
 logical::rdinqr
 call get_command_argument(1,path)
 call rdinit(74,0,trim(path))
 call rdstim('tstart',first);call rdstim('tend',last)
 open(newunit=u,file='capabilities.csv',status='new',action='write')
 write(u,'(a)')'kind,index,value'
 write(u,'(a,es25.16e3)')'calendar_start,0,',first
 write(u,'(a,es25.16e3)')'calendar_end,0,',last
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
  if(rdinqr(trim(name)))then
   call rdsint(trim(name),mode);write(u,'(a,a,i0)')trim(name),',0,',mode
  end if
 end do
 call rdinne('ncomp',n)
 if(n<1.or.n>256)error stop 'invalid original grid capacity'
 call rdfint('ncomp',counts,256,n)
 write(u,'(a,i0)')'nodes,0,',sum(counts(:n))
 call rdinne('croptype',n)
 if(n<1.or.n>64)error stop 'invalid original crop capacity'
 call rdfint('croptype',types,64,n)
 do i=1,n
  write(u,'(a,i0,a,i0)')'croptype,',i,',',types(i)
 end do
 close(74)
 close(u)
 print '(a)','SWP_HISTORICAL_INSPECTED'
end program inspect_historical
