# Bounded macropore candidate regression, not production admission.
# Each child gate compiles O0/O2, checks exit codes and compares transcripts.
$ErrorActionPreference = 'Stop'
$gates = @(
    'run_ppa_wu05a4_trial_exchange.ps1',
    'run_ppa_wu05a4_saturated_trial.ps1',
    'run_ppa_wu05a4_richards_scratch.ps1',
    'run_ppa_wu05a4_redistribution.ps1',
    'run_ppa_wu05a4_rate_composition.ps1',
    'run_ppa_wu05a4_outflow_limit.ps1',
    'run_ppa_wu05a4_inflow_limit.ps1',
    'run_ppa_wu05a3_interval_candidate.ps1',
    'run_ppa_wu05a3_candidate_mass.ps1'
)
foreach ($gate in $gates) {
    & (Join-Path $PSScriptRoot $gate)
}
'PPA_WU05A4_BOUNDED_REGRESSION_NINE_GATES=PASS'
