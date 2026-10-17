program test_surface_loss_order
 use iso_fortran_env,only:real64
 use mod_b111_surface_loss_budget
 implicit none
 type(surface_loss_receipt_t)::t,a,b
 real(real64)::tol
 tol=1d-12
 call evaluate_surface_loss_budget(1d0,2d0,1d0,1d0,0d0,0.5d0,0d0,0d0,3d0,0d0,0d0,t)
 if(t%status/=SURFACE_LOSS_OK)error stop 'single'
 if(abs(t%mass_end-3.75d0)>tol)error stop 'single mass'
 call evaluate_surface_loss_budget(1d0,2d0,1d0,0d0,0d0,0.25d0,0d0,0d0,0d0,0d0,0d0,a)
 if(a%status/=SURFACE_LOSS_OK)error stop 'prior infiltration'
 call evaluate_surface_loss_budget(a%depth_end,a%mass_end,1d0,1d0,0d0,0.25d0,0d0,0d0,3d0,0d0,0d0,b)
 if(b%status/=SURFACE_LOSS_OK)error stop 'post rain infiltration'
 if(abs(b%mass_end-3.857142857142857d0)>tol)error stop 'ordered mass'
 if(abs(b%depth_end-t%depth_end)>tol)error stop 'depth match'
 if(abs(b%mass_end-t%mass_end-0.107142857142857d0)>tol)error stop 'ordering sensitivity'
 print '(a)','SURFACE_LOSS_ORDER_PASS'
end program
