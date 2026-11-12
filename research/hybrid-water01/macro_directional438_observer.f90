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
   call vector_F(1,hgrad)
   write(filename,'(a,i3.3,a)') 'directional-',sample,'.txt'
   open(newunit=u,file=trim(filename),status='new',action='write')
   write(u,*) 'SAMPLE',sample,node,delta
   write(u,*) 'H',h(1:NN)
   write(u,*) 'F',F(1:NN)
   close(u)
   call shadow_end()
end subroutine directional_evaluate438
