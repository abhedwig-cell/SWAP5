param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Destination)
$ErrorActionPreference = 'Stop'
# Disposable numerical experiment: no production source or shared ABI edits.
$headcalc = Get-Content -Raw $Source
$headcalc = $headcalc.Replace('   use MOD_arrays,', @'
   use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t
   use mod_ppa_mvg_storage_binding, only: evaluate_bound_mvg_storage_difference
   use MOD_arrays,
'@)
$start = $headcalc.IndexOf('subroutine vector_F(iTask)')
$finish = $headcalc.IndexOf('end subroutine vector_F', $start)
if ($start -lt 0 -or $finish -lt 0) { throw 'Missing bounded vector_F region' }
$region = $headcalc.Substring($start,$finish-$start)
$pattern = '\(state%theta\((1|i|NN)\)\s*-\s*state%thetm1\(\1\)\)'
if ([regex]::Matches($region,$pattern).Count -ne 4) { throw 'Storage substitution count changed' }
$region = [regex]::Replace($region,$pattern,'storage_difference($1)')
$anchor = '   real(8)                    :: afgen'
if (-not $region.Contains($anchor)) { throw 'Missing residual declaration anchor' }
$region = $region.Replace($anchor, @'
   real(8)                    :: afgen
   real(8) :: storage_difference(numnod), trial_difference(numnod)
   logical :: storage_available

   storage_difference = state%theta(1:numnod)-state%thetm1(1:numnod)
   if (provider_constitutive_active .and. .not. legacy_state_binding .and. swmacro == 0 .and. swbotb == 7) then
  if (present(boundary_conditions)) then
     if (boundary_conditions%top_mode == FSI_TOP_MODE_EXPLICIT_FLUX) then
        select type (provider => evaluation_context%constitutive)
        type is (b110_default_mvg_provider_t)
           call evaluate_bound_mvg_storage_difference(provider, state%hm1(1:numnod), &
                state%thetm1(1:numnod), state%h(1:numnod), trial_difference, storage_available)
           if (storage_available) storage_difference = trial_difference
        end select
     end if
  end if
   end if
'@)
$headcalc = $headcalc.Substring(0,$start)+$region+$headcalc.Substring($finish)
# Mechanical bounded transformation of the tracked port, not a second source owner.
$headcalc | Set-Content $Destination
