! Authenticated B1.11 irrigation.f90 TCSFIX recurrence, unmodified statements.
 subroutine literal_fixed_interval(dayfix,irgdayfix,irrigevent)
 integer,intent(inout)::dayfix,irrigevent
 integer,intent(in)::irgdayfix
               if (irrigevent == 2 .AND. (dayfix >= irgdayfix)) then
                  irrigevent = 2
                  dayfix = 1
               else
                  irrigevent = 0
                  if (dayfix < irgdayfix) dayfix = dayfix + 1
               end if

 end subroutine
