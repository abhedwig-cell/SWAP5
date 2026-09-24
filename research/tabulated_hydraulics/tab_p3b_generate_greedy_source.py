#!/usr/bin/env python3
"""Generate research-only P3B greedy support placement in the table-state source."""
from pathlib import Path
import sys

src=Path(sys.argv[1]); dst=Path(sys.argv[2]); s=src.read_text()
old="""    u0 = log10(-GENERATION_H_DRY)
    do j = 1, B110_GENERATED_MVG_TABLE_N - 1
      frac = real(j-1,real64) / real(B110_GENERATED_MVG_TABLE_N-2,real64)
      do i = 1, n
        if (j == B110_GENERATED_MVG_TABLE_N - 1) then
          hvec(i) = lo(i)
        else if (B110_GENERATED_MVG_CURVATURE_GRID) then
          ! Research-only deterministic sparse placement.  Smoothstep has a
          ! smaller derivative at both ends of [0,1], so equal index spacing
          ! allocates more rows near both dry and wet ends of log-head space.
          grid_frac = frac*frac*(3.0_real64-2.0_real64*frac)
          hvec(i) = -10.0_real64**(u0 + grid_frac * (log10(-lo(i)) - u0))
        else
          hvec(i) = -10.0_real64**(u0 + frac * (log10(-lo(i)) - u0))
        end if
      end do
      call analytic%evaluate(hvec, theta, conductivity, capacity, dkdh)"""
new="""    ! P3B research-only greedy constitutive-error placement.
    ! Build a dense analytical authority grid for every active node, then
    ! greedily add the point with largest normalized piecewise-linear error
    ! in theta or log(K). Final interpolation below remains TSPACK.
    block
      integer, parameter :: dense_n = 2049
      real(real64), allocatable :: dense_h(:,:), dense_theta(:,:), dense_logk(:,:)
      real(real64), allocatable :: dense_k(:,:), dense_c(:,:), dense_dk(:,:)
      integer, allocatable :: support(:,:)
      logical, allocatable :: chosen(:,:)
      real(real64) :: f, score, best_score, thscale, lkscale, thlin, lklin, w
      integer :: q, best_q, left, right, kk
      allocate(dense_h(dense_n,n),dense_theta(dense_n,n),dense_logk(dense_n,n), &
               dense_k(dense_n,n),dense_c(dense_n,n),dense_dk(dense_n,n))
      allocate(support(B110_GENERATED_MVG_TABLE_N-1,n),chosen(dense_n,n))
      chosen=.false.
      do q=1,dense_n
        f=real(q-1,real64)/real(dense_n-1,real64)
        do i=1,n
          dense_h(q,i)=-10.0_real64**(log10(-GENERATION_H_DRY)+f*(log10(-lo(i))-log10(-GENERATION_H_DRY)))
        end do
        call analytic%evaluate(dense_h(q,:),dense_theta(q,:),dense_k(q,:),dense_c(q,:),dense_dk(q,:))
        dense_logk(q,:)=log(dense_k(q,:))
      end do
      do i=1,n
        support(1,i)=1; support(2,i)=dense_n
        chosen(1,i)=.true.; chosen(dense_n,i)=.true.
        do kk=3,B110_GENERATED_MVG_TABLE_N-1
          best_score=-1.0_real64; best_q=2
          do q=2,dense_n-1
            if(chosen(q,i)) cycle
            left=1
            do while(left<dense_n .and. .not.chosen(left,i)); left=left+1; end do
            left=q-1
            do while(left>1 .and. .not.chosen(left,i)); left=left-1; end do
            right=q+1
            do while(right<dense_n .and. .not.chosen(right,i)); right=right+1; end do
            w=(log10(-dense_h(q,i))-log10(-dense_h(left,i)))/(log10(-dense_h(right,i))-log10(-dense_h(left,i)))
            thlin=dense_theta(left,i)+w*(dense_theta(right,i)-dense_theta(left,i))
            lklin=dense_logk(left,i)+w*(dense_logk(right,i)-dense_logk(left,i))
            thscale=max(epsilon(1.0_real64),parameters%cofgen(2,i)-parameters%cofgen(1,i))
            lkscale=max(1.0_real64,abs(dense_logk(dense_n,i)-dense_logk(1,i)))
            score=max(abs(dense_theta(q,i)-thlin)/thscale,abs(dense_logk(q,i)-lklin))
            if(score>best_score) then; best_score=score; best_q=q; end if
          end do
          chosen(best_q,i)=.true.; support(kk,i)=best_q
        end do
        call sort_int(support(:,i))
        do j=1,B110_GENERATED_MVG_TABLE_N-1
          state%head(j,i)=dense_h(support(j,i),i)
          state%theta(j,i)=dense_theta(support(j,i),i)
          state%logk(j,i)=dense_logk(support(j,i),i)
        end do
      end do
      deallocate(dense_h,dense_theta,dense_logk,dense_k,dense_c,dense_dk,support,chosen)
    end block
    ! Values are already populated for rows 1:N-1 by the greedy authority.
    hvec=state%head(B110_GENERATED_MVG_TABLE_N-1,:)
    theta=state%theta(B110_GENERATED_MVG_TABLE_N-1,:)
    conductivity=exp(state%logk(B110_GENERATED_MVG_TABLE_N-1,:))
    ! The original generation loop terminator belongs to the replaced loop.
    ! Consume it here with a one-iteration block-compatible loop.
    do j=1,1"""
if old not in s: raise SystemExit("generation block not found")
s=s.replace(old,new)
# add a tiny deterministic integer sorter inside module before authority_theta
needle="  pure real(real64) function authority_theta(c,hv) result(theta)"
sorter="""  pure subroutine sort_int(a)
    integer, intent(inout) :: a(:)
    integer :: ii,jj,tmp
    do ii=2,size(a)
      tmp=a(ii); jj=ii-1
      do while(jj>=1)
        if(a(jj)<=tmp) exit
        a(jj+1)=a(jj); jj=jj-1
      end do
      a(jj+1)=tmp
    end do
  end subroutine sort_int

"""
if needle not in s: raise SystemExit("insertion point not found")
s=s.replace(needle,sorter+needle)
dst.write_text(s)
