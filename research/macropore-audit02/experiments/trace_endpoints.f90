subroutine trace02(stage)
 use iso_c_binding,only:c_int
 integer,intent(in)::stage
 integer::u,pid,ic
 integer(8),external::audit_hash,audit_macrohash
 integer(8)::hh,mh,qh
 logical,save::busy=.false.
 real(8)::oldF(macp),oldQ(macp),oldH(macp),oldT(macp),cached_h(macp)
 character(32)::file
 interface
  integer(c_int) function shadow_begin() bind(C,name='s5_shadow_begin')
   import c_int
  end function
  subroutine shadow_end() bind(C,name='s5_shadow_end')
  end subroutine
 end interface
 if(busy)return
 ! Observe each selected day's final live timestep, not a rebuilt daily average.
 if(t1900<36227d0.or.t1900>=36233d0)return
 if(t1900+dt<dble(floor(t1900)+1)-1d-10)return
 audit_seq=audit_seq+1
 hh=audit_hash(h,NN);qh=audit_hash(QExcMpMtx,NN);mh=audit_macrohash()
 open(newunit=u,file='trace02.txt',position='append',status='unknown')
 write(u,*) 'P',t1900,dt,numbit,itry,stage,audit_seq,flunsatok,IDecMpRat,hh,mh,qh, &
    maxval(abs(F(1:NN))),maxval(abs(h(1:NN)-audit_h(1:NN))),maxval(abs(QExcMpMtx(1:NN)-audit_q(1:NN)))
 close(u)
 if(stage/=2.and.stage/=4.and.stage/=5)return
 pid=shadow_begin()
 if(pid/=0)then
  if(pid<0)error stop 'audit child failed'
  return
 endif
 busy=.true.
 oldF=F;oldQ=QExcMpMtx;oldH=h;oldT=theta;cached_h=audit_h
 call vector_F(1,hgrad)
 open(newunit=u,file='trace02.txt',position='append',status='unknown')
 write(u,*) 'C',t1900,dt,numbit,itry,stage,audit_seq, &
 maxval(abs(oldF(1:NN))),maxval(abs(F(1:NN))),maxval(abs(QExcMpMtx(1:NN)-oldQ(1:NN))), &
 maxval(abs((F(1:NN)-oldF(1:NN))+(QExcMpMtx(1:NN)-oldQ(1:NN))))
 if(stage==5)then
  write(u,*) 'ACCEPT_H',oldH(1:NN)
  write(u,*) 'CACHE_H',cached_h(1:NN)
  write(u,*) 'ACCEPT_F',oldF(1:NN)
  write(u,*) 'FRESH_F',F(1:NN)
  write(u,*) 'CACHE_Q',oldQ(1:NN)
  write(u,*) 'FRESH_Q',QExcMpMtx(1:NN)
 endif
 close(u)
 call shadow_end()
end subroutine trace02
