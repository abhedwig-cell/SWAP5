program original_tabulated_drainage
 use MOD_grid,only:numnod
 use MOD_swap_base,only:swmacro
 use MOD_drain,only:dramet,nrlevs,swdivd,qdrtab,qdrain,qdra,qdrtot
 use variables,only:gwl
 implicit none
 integer::table_index,point_index,count_cases
 real(8)::left,right,expected,depths(5),values(5)
 numnod=2;swmacro=0;dramet=1;nrlevs=1;swdivd=0;count_cases=0
 depths=[0d0,-20d0,-60d0,-100d0,999d0]
 do table_index=1,3
 select case(table_index)
 case(1)
 left=.5d0;right=.125d0
 case(2)
 left=.25d0;right=-.25d0
 case(3)
 left=0d0;right=0d0
 end select
 qdrtab=0d0;qdrtab(1:4)=[20d0,left,100d0,right]
 values=[left,left,(left+right)/2d0,right,0d0]
 do point_index=1,5
 qdra=0d0;qdrain=0d0;qdrtot=0d0;gwl=depths(point_index)
 call Drainage()
 expected=values(point_index)
 if(qdrtot/=expected.or.qdrain(1)/=expected.or.sum(qdra(1,1:numnod))/=expected)then
 write(*,*)table_index,point_index,qdrtot,expected
 error stop 'Actual original tabulated drain flux or partition differs'
 endif
 count_cases=count_cases+1
 write(*,'(a,2i4,4es26.17)')'TABLE_DRAIN',table_index,point_index,gwl,qdrtot,qdra(1,1),qdra(1,2)
 enddo
 enddo
 if(count_cases/=15)error stop 'Missing original tabulated drainage case'
end program
