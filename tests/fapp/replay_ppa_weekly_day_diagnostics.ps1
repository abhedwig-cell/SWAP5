# Replay optional diagnostics from an explicitly supplied clean owner-gate build.
# PASS means the documented negative fixtures were reproduced, not day2 success.
param([Parameter(Mandatory=$true)][string]$BuildDirectory)
$ErrorActionPreference = 'Stop'
$build = (Resolve-Path -LiteralPath $BuildDirectory).Path
$cases = @{
    baseline = '--weekly-full-day'
    coarse = '--weekly-full-day-coarse'
    extended = '--weekly-full-day-dense'
}
$observed = @{}
foreach ($opt in @('O0','O2')) {
    $exe = Join-Path $build "$opt/ppa_free_drainage_owner.exe"
    if (!(Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Missing executable: $exe" }
}
foreach ($case in @('baseline','coarse','extended')) {
    foreach ($opt in @('O0','O2')) {
        $exe = Join-Path $build "$opt/ppa_free_drainage_owner.exe"
        # Native error output is expected, but an arbitrary crash is not success.
        $output = @(& $exe --irrigation-source $cases[$case] 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
        $output | Set-Content -LiteralPath (Join-Path $build "$opt/weekly-$case-diagnostic.txt")
        if ($code -eq 0) { throw "$case $opt changed to success: requalify rather than silently accepting" }
        $required = @('PPA_IRR_FULL_DAY_EXPERIMENT_NO_PUBLICATION=PASS')
        if ($case -eq 'coarse') {
            $required += @('PPA_IRR_FULL_DAY_COMPLETED=F;STATUS=2','ERROR STOP full-day qualification incomplete')
        } else {
            $required += @('PPA_IRR_FULL_DAY_COMPLETED=T;STATUS=0',
                'PPA_IRR_FULL_DAY_COMMIT_DECODED_RESTART_IDENTITY=PASS',
                'PPA_IRR_FULL_DAY_REPLAY=1;COMPLETED=F;STATUS=2',
                'PPA_IRR_DAY2_TERMINAL_STORAGE_QUAD_ORACLE=PASS',
                'PPA_IRR_DAY2_FAILURE_ROLLBACK=PASS','ERROR STOP full-day replay incomplete')
        }
        foreach ($marker in $required) {
            if (!($output -ccontains $marker)) { throw "Missing $case $opt marker: $marker" }
        }
        # Backtrace addresses and wall time are not numerical identity evidence.
        $observed["$case-$opt"] = (@($output | Where-Object {
            $_ -match '^PPA_' -and $_ -notmatch '^PPA_IRR_FULL_DAY_WALL_SECONDS='
        }) -join "`n")
    }
    if ($observed["$case-O0"] -cne $observed["$case-O2"]) { throw "$case O0/O2 diagnostic mismatch" }
    "PPA_WEEKLY_${case}_NEGATIVE_FIXTURE_IDENTITY=PASS"
}
'PPA_WEEKLY_DAY2_COMPLETION=NOT_QUALIFIED'
