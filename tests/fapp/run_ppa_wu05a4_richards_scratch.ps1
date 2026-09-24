$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$build = Join-Path ([IO.Path]::GetTempPath()) ('swap-richards-scratch-' + [guid]::NewGuid().ToString('N'))
$outputs = @()
foreach ($opt in @('O0','O2')) {
    $dir = Join-Path $build $opt
    New-Item -ItemType Directory $dir -Force | Out-Null
    $exe = Join-Path $dir 'test.exe'
    $matrixLevelSource = Join-Path $repo 'src/process/mod_ppa_wu05a4_matrix_level.f90'
    # The existing abstract solver default has intentionally unused dummy arguments.
    $arguments = @('-J',$dir,'-I',$dir,'-std=f2008','-Wall','-Wextra','-Werror','-Wno-unused-dummy-argument','-fcheck=all','-ffpe-trap=invalid,zero,overflow',"-$opt")
    $arguments += $matrixLevelSource
    $arguments += (Join-Path $repo 'src/solver/mod_ppa_wu05a4_reduction_policy.f90')
    $arguments += (Join-Path $repo 'src/process/mod_ppa_wu05a4_matrix_fraction.f90')
    foreach ($source in @('src/adapter/mod_ppa_wu05a2_macropore_state.f90',
        'src/adapter/mod_ppa_wu05a3_candidate_mass.f90',
        'src/process/mod_ppa_wu05a3_macrostate_storage_candidate.f90',
        'src/process/mod_ppa_wu05a3_macrostate_wetting_candidate.f90',
        'src/process/mod_ppa_wu05a3_conservative_flux.f90',
        'src/process/mod_ppa_wu05a3_sorptivity_events.f90',
        'src/adapter/mod_ppa_wu05a3_interval_candidate.f90')) {
        $arguments += (Join-Path $repo $source)
    }
    foreach ($source in @('src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_reference_richards_workspace.f90','src/process/mod_ppa_wu05a3_volundr.f90','src/process/mod_ppa_wu05a4_storage_bounds.f90','src/process/mod_ppa_wu05a3_satflow_exchange.f90','src/process/mod_ppa_wu05a3_satflow_task1.f90','src/process/mod_ppa_wu05a3_satflow_derivative.f90','src/process/mod_ppa_wu05a4_inflow_limit.f90','src/process/mod_ppa_wu05a4_outflow_limit.f90','src/solver/mod_ppa_wu05a4_trial_exchange.f90','src/adapter/mod_ppa_wu05a4_saturated_trial.f90','src/adapter/mod_ppa_wu05a4_richards_scratch_binding.f90','tests/fapp/test_ppa_wu05a4_richards_scratch.f90')) {
        $arguments += (Join-Path $repo $source)
    }
    $arguments += @('-o',$exe)
    & gfortran @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Compilation failed' }
    $result = & $exe 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $result" }
    $outputs += ,($result -join "`n")
}
if ($outputs[0] -cne $outputs[1]) { throw 'O0/O2 differ' }
$outputs[0]
'PPA_WU05A4_REFERENCE_SCRATCH_O0_O2_IDENTITY=PASS'
