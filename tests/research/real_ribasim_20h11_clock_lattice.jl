using Ribasim
import BasicModelInterface as BMI

const HOUR = 3600.0
const CALL_ENDS = [6, 12, 18, 24, 30, 36] .* HOUR
const TIME_TOL = 1.0e-6

const CASES = [
    ("A4", [0, 12, 24] .* HOUR, 12 * HOUR),
    ("A5", [0, 30] .* HOUR, 30 * HOUR),
    ("A8", [0, 24] .* HOUR, 24 * HOUR),
    ("A6", [0, 6, 12, 18, 24, 30] .* HOUR, 6 * HOUR),
]

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function unique_record_times(model)
    allocation = model.integrator.p.p_independent.allocation
    return sort(unique(Float64(d.time) for d in allocation.record_demand))
end

function check_times(label, observed, expected)
    require(length(observed) == length(expected),
        "$label record count $(length(observed)) != $(length(expected)); observed=$observed")
    for (a, b) in zip(observed, expected)
        require(isapprox(a, b; atol=TIME_TOL, rtol=0.0),
            "$label record time $a != frozen $b")
    end
end

function main()
    length(ARGS) == 1 || error("usage: real_ribasim_20h11_clock_lattice.jl <case-root>")
    root = abspath(ARGS[1])
    for (label, expected, effective) in CASES
        path = joinpath(root, label, "ribasim.toml")
        require(isfile(path), "$label model missing")
        model = BMI.initialize(Ribasim.Model, path)
        try
            for endpoint in CALL_ENDS
                BMI.update_until(model, endpoint)
                require(isapprox(BMI.get_current_time(model), endpoint; atol=TIME_TOL, rtol=0.0),
                    "$label BMI endpoint mismatch at $endpoint")
            end
            observed = unique_record_times(model)
            check_times(label, observed, expected)
            cumulative = BMI.get_value_ptr(model, "user_demand.cumulative_inflow")
            level = BMI.get_value_ptr(model, "basin.level")[1]
            println(
                "RIBASIM_REAL_20H11_CASE case=$label " *
                "observed_seconds=$observed expected_seconds=$expected " *
                "effective_repeat_s=$effective root_m3=$(cumulative[1]) " *
                "external_m3=$(cumulative[2]) level=$level"
            )
        finally
            BMI.finalize(model)
        end
    end
    println("RIBASIM_REAL_20H11_FIXED_ALLOCATION_BMI_CLOCK_LATTICE=PASS")
end

main()
