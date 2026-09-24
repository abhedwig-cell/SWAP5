param([switch]$StableStorageExperiment)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$build = Join-Path $env:TEMP ('swap-free-drainage-' + [guid]::NewGuid())
New-Item -ItemType Directory $build | Out-Null
$gate = Get-Content -Raw (Join-Path $PSScriptRoot 'run_fsi38_prescribed_qbot_temporal_certificate_gate.sh')
$sources = [regex]::Match($gate, '(?s)MODULE_SRC=\((.*?)\)').Groups[1].Value.Trim() -split '\s+'
$sources = @($sources | ForEach-Object {
    if ($_ -eq 'src/runtime/mod_a23bu_worker_execution_context.f90') {
        'src/solver/mod_soil_water_accepted_step_direction_contract.f90'
        'src/transaction/mod_accepted_trajectory_directional_sensitivity.f90'
    }
    if ($_ -eq 'src/solver/mod_reference_richards_temporal_indicator.f90') {
        'src/solver/mod_b110_root_sink_provider.f90'
    }
    $_
}) + @('src/solver/mod_b110_default_mvg_directional_provider.f90', 'src/adapter/mod_ppa_free_drainage_stiffness.f90', 'src/adapter/mod_ppa_free_drainage_temporal_indicator.f90')
$flags = @('-g','-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow')
$tests = @('test_ppa_free_drainage_small_dt')
if ($StableStorageExperiment) {
    # Disposable numerical experiment: no production source or shared ABI edits.
    $headcalc = Get-Content -Raw (Join-Path $root 'src/legacy/b1_10_port/headcalc.f90')
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
    $candidate = Join-Path $build 'headcalc_storage_experiment.f90'
    # Mechanical bounded transformation of the tracked port, not a second source owner.
    $headcalc | Set-Content $candidate
    $sources = @($sources | ForEach-Object {
        if ($_ -eq 'src/legacy/b1_10_port/headcalc.f90') {
            'src/solver/mod_ppa_mvg_storage_difference.f90'
            'src/adapter/mod_ppa_mvg_storage_binding.f90'
        }
        $_
    })
}
foreach ($opt in 0,2) {
    $out = Join-Path $build "O$opt"
    New-Item -ItemType Directory $out | Out-Null
    $objects = @()
    foreach ($source in $sources) {
        $obj = Join-Path $out (([IO.Path]::GetFileNameWithoutExtension($source))+'.o')
        $sourcePath = Join-Path $root $source
        if ($StableStorageExperiment -and $source -eq 'src/legacy/b1_10_port/headcalc.f90') { $sourcePath = $candidate }
        & gfortran @flags "-O$opt" -J $out -I $out -c $sourcePath -o $obj
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $source" }
        $objects += $obj
    }
    foreach ($test in $tests) {
        $exe = Join-Path $out "$test.exe"
        & gfortran @flags "-O$opt" -J $out -I $out (Join-Path $PSScriptRoot "$test.f90") @objects -o $exe
        if ($LASTEXITCODE -ne 0) { throw "Test compilation failed: $test" }
        $argsForTest = @()
        if ($test -like 'test_fsi25*') { $argsForTest = @('-75.0','0.01') }
        $lines = & $exe @argsForTest
        if ($LASTEXITCODE -ne 0) { $lines; throw "Test failed: $test O$opt" }
        if (($lines -join "`n") -notmatch 'PASS') { throw "Missing PASS: $test" }
        $lines | Set-Content (Join-Path $out "$test.txt")
        $lines
    }
}
foreach ($test in $tests) {
    if ((Get-Content -Raw (Join-Path $build "O0/$test.txt")) -cne (Get-Content -Raw (Join-Path $build "O2/$test.txt"))) {
        throw "O0/O2 transcript mismatch: $test"
    }
}
Write-Output 'FREE_DRAINAGE_SMALL_DT_O0_O2_DIAGNOSTIC=PASS'
if ($StableStorageExperiment) { Write-Output 'EXPERIMENTAL_STORAGE_RESIDUAL_ONLY=YES' }
Write-Output "BUILD=$build"
