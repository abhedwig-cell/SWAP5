$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$build = Join-Path ([IO.Path]::GetTempPath()) ('swap5-interval-candidate-' + [guid]::NewGuid().ToString('N'))
$sources = @('src/adapter/mod_ppa_wu05a2_macropore_state.f90',
    'src/process/mod_ppa_wu05a3_macrostate_storage_candidate.f90',
    'src/process/mod_ppa_wu05a3_macrostate_wetting_candidate.f90',
    'src/process/mod_ppa_wu05a3_conservative_flux.f90',
    'src/adapter/mod_ppa_wu05a3_interval_candidate.f90',
    'tests/fapp/test_ppa_wu05a3_interval_candidate.f90')
$outputs = @()
foreach ($optimization in @('O0', 'O2')) {
    $directory = Join-Path $build $optimization
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $executable = Join-Path $directory 'oracle.exe'
    $arguments = @('-J', $directory, '-I', $directory, '-std=f2008', '-Wall', '-Wextra', '-Werror',
        '-fcheck=all', '-ffpe-trap=invalid,zero,overflow', "-$optimization")
    foreach ($source in $sources) { $arguments += (Join-Path $repo $source) }
    $arguments += @('-o', $executable)
    & gfortran @arguments
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $optimization" }
    $result = & $executable 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $optimization : $result" }
    $outputs += ,($result -join "`n")
}
if ($outputs[0] -cne $outputs[1]) { throw 'O0/O2 transcripts differ' }
$outputs[0]
'PPA_WU05A3_INTERVAL_O0_O2_IDENTITY=PASS'
