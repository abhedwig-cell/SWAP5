program crc_driver
 use iso_fortran_env,only:int8,int32
 use mod_age_joint_restart_file,only:crc32
 implicit none
 integer(int8),allocatable::bytes(:)
 character(1024)::path
 integer::n,u
 call get_command_argument(1,path)
 inquire(file=trim(path),size=n)
 allocate(bytes(n))
 open(newunit=u,file=trim(path),access='stream',form='unformatted',status='old')
 read(u)bytes
 close(u)
 write(*,'(z8.8)')crc32(bytes)
end program
