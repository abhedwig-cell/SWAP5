 subroutine saved_calendar_plan(plan)
  type(soil_n_amendment_calendar_t),intent(out)::plan
  type(soil_n_material_input_t)::source(2)
  type(b111_soil_n_material_t)::definitions(3)
  integer::code
  call materials(source,split)
  definitions=[source(1)%material,source(1)%material,source(2)%material]
  definitions%application_kg_m2=0d0
  call create_soil_n_amendment_calendar(4d0,[4d0,6d0,6d0],[400d0,200d0,300d0],definitions,plan,code)
  call require(code==0,'immutable saved-calendar fixture construction')
 end subroutine
 subroutine saved_calendar_manual_batch(day,batch)
  ! Independent fixture oracle. Do not call the production calendar selector.
  integer,intent(in)::day
  type(soil_n_material_input_t),allocatable,intent(out)::batch(:)
  type(soil_n_material_input_t)::source(2)
  call materials(source,split)
  select case(day)
  case(4)
   allocate(batch(1));batch(1)=source(1)
   batch(1)%kind=MATERIAL_AMENDMENT;batch(1)%material%application_kg_m2=400d0*1d-4
  case(6)
   allocate(batch(2));batch=source
   batch%kind=MATERIAL_AMENDMENT
   batch(1)%material%application_kg_m2=200d0*1d-4
   batch(2)%material%application_kg_m2=300d0*1d-4
  case default
   allocate(batch(0))
  end select
 end subroutine
