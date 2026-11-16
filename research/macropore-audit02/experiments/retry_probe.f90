subroutine retry_probe02()
 use iso_c_binding,only:c_int
 integer,external::audit_ready
 integer::mode,pid,u
 character(32)::file
 interface
  integer(c_int) function shadow_begin() bind(C,name='s5_shadow_begin')
   import c_int
  end function
  subroutine shadow_end() bind(C,name='s5_shadow_end')
  end subroutine
 end interface
 if(audit_ready()/=1)return
 do mode=0,1
  pid=shadow_begin()
  if(pid/=0)then
   if(pid<0)error stop 'retry comparison failed'
   cycle
  endif
  if(mode==1)call audit_restore_macro()
  call vector_F(1,hgrad)
  write(file,'(a,i1,a)')'retry-eval-',mode,'.txt'
  open(newunit=u,file=trim(file),status='new')
  write(u,*)'META',t1900,dt,IDecMpRat
  write(u,*)'Q',QExcMpMtx(1:NN)
  write(u,*)'F',F(1:NN)
  close(u)
  call shadow_end()
 enddo
end subroutine retry_probe02
