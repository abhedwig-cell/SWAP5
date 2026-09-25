param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Destination)
$ErrorActionPreference = 'Stop'
# Disposable observation-only copy. Never overwrite the reference source.
if ([IO.Path]::GetFullPath($Source) -eq [IO.Path]::GetFullPath($Destination)) {
    throw 'Convergence trace requires a separate destination'
}
$headcalc = Get-Content -Raw $Source
$anchor = '!  Convergence could not been reached'
if ([regex]::Matches($headcalc, [regex]::Escape($anchor)).Count -ne 1) {
    throw 'Expected exactly one convergence-exhaustion anchor'
}
$trace = @'
!  Observation only: executed after iteration exhaustion, before state rollback.
   write(*,*) 'PPA_CONVERGENCE_EXHAUSTED', dt, NN, &
        count(fsi_ws%nonconverged_balance(1:NN)), count(fsi_ws%nonconverged_head(1:NN)), &
        flnonconv3, dabs(sum1) > CritDevBalTot
   write(*,*) 'PPA_CONVERGENCE_RESIDUAL', maxval(dabs(fsi_ws%residual(1:NN))), &
        CritDevBalCp, sum1, CritDevBalTot
   do j = 1, NN
      write(*,*) 'PPA_CONVERGENCE_NODE', j, fsi_ws%residual(j), state%h(j), &
           fsi_ws%old_head(j), state%hm1(j)
   end do
'@
$headcalc.Replace($anchor, $trace + "`n" + $anchor) | Set-Content $Destination
