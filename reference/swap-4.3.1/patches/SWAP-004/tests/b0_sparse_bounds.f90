program swap004_b0_sparse
  implicit none
  integer,allocatable::iTT1(:),iTT2(:)
  integer::Ntill,Ntypes,i,j,itype,nlay
  integer::Type_Tillage(1),iType_Tillage(2)
  Ntill=1; Ntypes=2; Type_Tillage=[3]; iType_Tillage=[3,3]
  allocate(iTT1(Ntill)); iTT1=0
  allocate(iTT2(Ntill)); iTT2=0
  do j=1,Ntill
    do i=1,Ntypes
      if(iTT1(j)==0 .and. iType_Tillage(i)==j) iTT1(j)=i
      if(iTT1(j)>0 .and. iType_Tillage(i)==j) iTT2(j)=i
    end do
  end do
  itype=Type_Tillage(1)
  nlay=iTT2(itype)-iTT1(itype)+1
  print *,nlay
end program
