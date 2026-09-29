$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$build = Join-Path ([IO.Path]::GetTempPath()) ('swap-saturated-' + [guid]::NewGuid().ToString('N'))
$outputs = @()
foreach ($opt in @('O0','O2')) {
    $dir = Join-Path $build $opt
    New-Item -ItemType Directory $dir -Force | Out-Null
    $exe = Join-Path $dir 'test.exe'
    $arguments = @('-J',$dir,'-I',$dir,'-std=f2008','-Wall','-Wextra','-Werror','-fcheck=all','-ffpe-trap=invalid,zero,overflow',"-$opt")
    $arguments += (Join-Path $repo 'src/process/mod_ppa_wu05a4_matrix_level.f90')
    foreach ($source in @('src/process/mod_ppa_wu05a3_volundr.f90','src/process/mod_ppa_wu05a4_storage_bounds.f90','src/process/mod_ppa_wu05a3_satflow_exchange.f90','src/process/mod_ppa_wu05a3_satflow_task1.f90','src/process/mod_ppa_wu05a3_satflow_derivative.f90','src/process/mod_ppa_wu05a4_inflow_limit.f90','src/process/mod_ppa_wu05a4_outflow_limit.f90','src/solver/mod_ppa_wu05a4_trial_exchange.f90','src/adapter/mod_ppa_wu05a4_saturated_trial.f90','tests/fapp/test_ppa_wu05a4_saturated_trial.f90')) {
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
'PPA_WU05A4_SATURATED_TRIAL_O0_O2_IDENTITY=PASS'
