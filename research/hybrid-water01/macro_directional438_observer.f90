subroutine shadow438(stage)
   use iso_c_binding, only: c_int
   integer, intent(in) :: stage
   integer :: pid_status, u, direction, scale, signum, sample
   integer, parameter :: nodes(8) = [1,40,56,60,80,81,90,112]
   real(8) :: delta
   interface
      integer(c_int) function shadow_begin() bind(C,name='s5_shadow_begin')
         import c_int
      end function
      subroutine shadow_end() bind(C,name='s5_shadow_end')
      end subroutine
   end interface
   if (t1900 < 36232d0 .or. t1900 >= 36233d0 .or. t1900+dt < 36233d0-1d-10) return
   pid_status=shadow_begin()
   if (pid_status /= 0) then
      if (pid_status < 0) error stop 'Directional observation child failed'
      return
   end if
   ! Every evaluation forks this unchanged live state, not the preceding evaluation.
   call directional_evaluate438(0,0,0d0)
   call directional_evaluate438(1,0,0d0)
   sample=2
   do direction=1,size(nodes)
      do scale=1,2
         do signum=-1,1,2
            delta=signum*1d-4/(2d0**(scale-1))
            call directional_evaluate438(sample,nodes(direction),delta)
            sample=sample+1
         end do
      end do
   end do
   call history_evaluate438()
   call analytic_evaluate438()
   open(newunit=u,file='day438-shadow.txt',status='new',action='write')
   write(u,*) 'DERIVATIVE_META',stage,t1900,dt,NN,swbotb,numbit,flunsatok
   write(u,*) 'SAMPLES',sample
   close(u)
   call shadow_end()
end subroutine shadow438

subroutine directional_evaluate438(sample,node,delta)
   use iso_c_binding, only: c_int
   integer, intent(in) :: sample,node
   real(8), intent(in) :: delta
   integer :: pid_status,u,ic
   real(8) :: cached_F(macp),cached_Q(macp)
   character(32) :: filename
   interface
      integer(c_int) function shadow_begin() bind(C,name='s5_shadow_begin')
         import c_int
      end function
      subroutine shadow_end() bind(C,name='s5_shadow_end')
      end subroutine
   end interface
   pid_status=shadow_begin()
   if (pid_status /= 0) then
      if (pid_status < 0) error stop 'Directional sample failed'
      return
   end if
   if (node > 0) then
      h(node)=h(node)+delta
      theta(node)=watcon(node,h(node))
   end if
   ! Original SWKIMPL=0 contract: frozen step conductivities and root rates.
   ! Only trial theta and pressure gradients follow the perturbed trial pressure.
   do ic=2,NN
      hgrad(ic)=(h(ic-1)-h(ic))/disnod(ic)+1d0
   end do
   cached_F=F
   cached_Q=QExcMpMtx
   call vector_F(1,hgrad)
   write(filename,'(a,i3.3,a)') 'directional-',sample,'.txt'
   open(newunit=u,file=trim(filename),status='new',action='write')
   write(u,*) 'SAMPLE',sample,node,delta
   write(u,*) 'H',h(1:NN)
   write(u,*) 'F',F(1:NN)
   write(u,*) 'Q',QExcMpMtx(1:NN)
   write(u,*) 'CACHED_F',cached_F(1:NN)
   write(u,*) 'CACHED_Q',cached_Q(1:NN)
   close(u)
   call shadow_end()
end subroutine directional_evaluate438

subroutine history_evaluate438()
   use iso_c_binding, only: c_int
   use MOD_macropore, only: NumDm, FrMpWalWet, WaUnMpDmCp, FlEndSrpEvt
   integer :: pid_status,u,iteration,ic
   real(8) :: base_h(macp),base_theta(macp)
   character(16) :: tag
   interface
      integer(c_int) function shadow_begin() bind(C,name='s5_shadow_begin')
         import c_int
      end function
      subroutine shadow_end() bind(C,name='s5_shadow_end')
      end subroutine
   end interface
   pid_status=shadow_begin()
   if (pid_status /= 0) then
      if (pid_status < 0) error stop 'History sample failed'
      return
   end if
   base_h=h
   base_theta=theta
   open(newunit=u,file='history438.txt',status='new',action='write')
   do iteration=1,4
      if (iteration == 3) then
         h(81)=-abs(base_h(81))-0.01d0
         theta(81)=watcon(81,h(81))
      end if
      if (iteration == 4) then
         h=base_h
         theta=base_theta
      end if
      do ic=2,NN
         hgrad(ic)=(h(ic-1)-h(ic))/disnod(ic)+1d0
      end do
      call vector_F(1,hgrad)
      write(tag,'(a,i1)') 'F',iteration
      write(u,*) trim(tag),F(1:NN)
      write(tag,'(a,i1)') 'H',iteration
      write(u,*) trim(tag),h(1:NN)
      write(tag,'(a,i1)') 'THETA',iteration
      write(u,*) trim(tag),theta(1:NN)
      write(tag,'(a,i1)') 'WET',iteration
      write(u,*) trim(tag),FrMpWalWet(1:NumDm,1:NN)
      write(tag,'(a,i1)') 'UNSAT',iteration
      write(u,*) trim(tag),WaUnMpDmCp(1:NumDm,1:NN)
      write(tag,'(a,i1)') 'EVENT',iteration
      write(u,*) trim(tag),FlEndSrpEvt(1:NumDm,1:NN)
   end do
   close(u)
   call shadow_end()
end subroutine history_evaluate438

subroutine analytic_evaluate438()
   use iso_c_binding, only: c_int
   integer :: pid_status,u
   interface
      integer(c_int) function shadow_begin() bind(C,name='s5_shadow_begin')
         import c_int
      end function
      subroutine shadow_end() bind(C,name='s5_shadow_end')
      end subroutine
   end interface
   pid_status=shadow_begin()
   if (pid_status /= 0) then
      if (pid_status < 0) error stop 'Analytic sample failed'
      return
   end if
   call vector_F(1,hgrad)
   open(newunit=u,file='analytic438.txt',status='new',action='write')
   write(u,*) 'Q_RATE',QExcMpMtx(1:NN)
   call MACROPORE(3)
   write(u,*) 'Q_PAIR',QExcMpMtx(1:NN)
   write(u,*) 'DQ_ANALYTIC',dFdhMp(1:NN)
   close(u)
   call shadow_end()
end subroutine analytic_evaluate438
