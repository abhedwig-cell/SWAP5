program test_crop_rotation_calendar
 use, intrinsic :: iso_fortran_env, only: real64
 use mod_crop_rotation_calendar
 implicit none
 type(crop_calendar_t) :: c
 integer :: stat,idx
 logical :: active,begins
 call initialize_crop_calendar([100.0_real64,200.0_real64], &
      [150.0_real64,240.0_real64],c,stat)
 call req(stat==CROP_CAL_OK,'initialize')
 call req(c%size()==2,'size')
 call c%select_at(100.0_real64,idx,active,begins,stat)
 call req(stat==CROP_CAL_OK.and.idx==1.and.active.and.begins,'first start')
 call c%select_at(150.0_real64,idx,active,begins,stat)
 call req(stat==CROP_CAL_OK.and.idx==1.and.active.and..not.begins,'end inclusive')
 call c%select_at(180.0_real64,idx,active,begins,stat)
 call req(stat==CROP_CAL_OUTSIDE.and..not.active,'fallow')
 call c%select_at(200.0_real64,idx,active,begins,stat)
 call req(stat==CROP_CAL_OK.and.idx==2.and.begins,'second start')
 call c%select_at(245.0_real64,idx,active,begins,stat)
 call req(stat==CROP_CAL_OUTSIDE.and..not.active,'post harvest')
 call initialize_crop_calendar([100.0_real64,149.0_real64], &
      [150.0_real64,190.0_real64],c,stat)
 call req(stat==CROP_CAL_OVERLAP.and..not.c%ready(),'overlap fail closed')
 call initialize_crop_calendar([100.0_real64], [99.0_real64],c,stat)
 call req(stat==CROP_CAL_INVALID,'reversed')
 print '(a)','SW431_CROP_CALENDAR_SELECTOR=PASS'
contains
 subroutine req(ok,message)
 logical,intent(in)::ok
 character(*),intent(in)::message
 if(.not.ok) then
 print *, 'FAIL:',message
 error stop 1
 end if
 end subroutine
end program
