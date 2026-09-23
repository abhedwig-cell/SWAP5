using Ribasim
import BasicModelInterface as BMI

const DT_DAY = 1.0e-4
const DURATION_SECONDS = 8.64
const LEVEL_TOL = 1.0e-8
const STORAGE_TOL = 1.0e-8
const DISCHARGE_TOL = 1.0e-8
const MASS_TOL = 1.0e-8
const INITIAL_TOL = 1.0e-10
const ORACLE_MASS_TOL_CM = 1.0e-12

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function parse_oracle(path::AbstractString)
    rows = NamedTuple[]
    for line in eachline(path)
        startswith(line, "Q1A_CASE,") || continue
        fields = split(strip(line), ",")
        length(fields) == 9 || error("unexpected oracle row: $line")
        push!(rows, (
            id = fields[2],
            initial_storage_cm = parse(Float64, fields[3]),
            initial_level_cm = parse(Float64, fields[4]),
            drainage_cm_day = parse(Float64, fields[5]),
            final_storage_cm = parse(Float64, fields[6]),
            final_level_cm = parse(Float64, fields[7]),
            discharge_cm_day = parse(Float64, fields[8]),
            mass_residual_cm = parse(Float64, fields[9]),
        ))
    end
    require(length(rows) == 3, "oracle case count drift")
    return rows
end

function only_value(values, label)
    require(length(values) == 1, "Q1A-R3L requires exactly one $label")
    return Float64(values[1])
end

basin_level(model) = only_value(BMI.get_value_ptr(model, "basin.level"), "Basin level")
basin_storage(model) = only_value(BMI.get_value_ptr(model, "basin.storage"), "Basin storage")
pump_cumulative(model) = only_value(model.integrator.u.pump, "Pump cumulative-flow state")

function run_case(root::AbstractString, case)
    path = joinpath(root, case.id, "ribasim.toml")
    model = BMI.initialize(Ribasim.Model, path)
    try
        initial_level = basin_level(model)
        initial_storage = basin_storage(model)
        initial_pump = pump_cumulative(model)

        require(
            abs(initial_level - case.initial_level_cm / 100.0) <= INITIAL_TOL,
            "$(case.id) initial level drift $initial_level",
        )
        require(
            abs(initial_storage - case.initial_storage_cm * 0.01) <= INITIAL_TOL,
            "$(case.id) initial storage drift $initial_storage",
        )

        BMI.update_until(model, DURATION_SECONDS)
        require(
            isapprox(BMI.get_current_time(model), DURATION_SECONDS; atol=1.0e-8, rtol=0.0),
            "$(case.id) endpoint mismatch",
        )

        final_level = basin_level(model)
        final_storage = basin_storage(model)
        direct_discharge = pump_cumulative(model) - initial_pump
        drainage_input = case.drainage_cm_day * 0.01 * DT_DAY
        direct_mass_residual =
            final_storage - initial_storage - drainage_input + direct_discharge

        oracle_level = case.final_level_cm / 100.0
        oracle_storage = case.final_storage_cm * 0.01
        oracle_discharge = case.discharge_cm_day * DT_DAY * 0.01

        require(abs(case.mass_residual_cm) <= ORACLE_MASS_TOL_CM,
            "$(case.id) oracle residual $(case.mass_residual_cm)")
        require(abs(final_level - oracle_level) <= LEVEL_TOL,
            "$(case.id) level mismatch ribasim=$final_level oracle=$oracle_level")
        require(abs(final_storage - oracle_storage) <= STORAGE_TOL,
            "$(case.id) storage mismatch ribasim=$final_storage oracle=$oracle_storage")
        require(abs(direct_discharge - oracle_discharge) <= DISCHARGE_TOL,
            "$(case.id) direct discharge mismatch ribasim=$direct_discharge oracle=$oracle_discharge")
        require(abs(direct_mass_residual) <= MASS_TOL,
            "$(case.id) direct mass residual $direct_mass_residual")

        if case.id == "C0_NO_DISCHARGE"
            require(abs(direct_discharge) <= DISCHARGE_TOL,
                "C0 direct Pump discharge $direct_discharge")
        else
            require(direct_discharge > 0.0, "$(case.id) direct Pump discharge is not positive")
        end

        println("SW_RIB_SWM01_Q1A_R3L_CASE=$(case.id)")
        println("  FINAL_LEVEL_RIBASIM_M=$final_level")
        println("  FINAL_LEVEL_ORACLE_M=$oracle_level")
        println("  FINAL_STORAGE_RIBASIM_M3=$final_storage")
        println("  FINAL_STORAGE_ORACLE_M3=$oracle_storage")
        println("  DIRECT_PUMP_DISCHARGE_M3=$direct_discharge")
        println("  ORACLE_DISCHARGE_M3=$oracle_discharge")
        println("  DIRECT_MASS_RESIDUAL_M3=$direct_mass_residual")
        println("SW_RIB_SWM01_Q1A_R3L_CASE_PASS=$(case.id)")
    finally
        BMI.finalize(model)
    end
end

function main()
    length(ARGS) == 2 || error("usage: q1a_r3_direct_ledger.jl <oracle.csv> <model-root>")
    rows = parse_oracle(abspath(ARGS[1]))
    root = abspath(ARGS[2])
    for case in rows
        run_case(root, case)
    end
    println("SW_RIB_SWM01_Q1A_R3_DIRECT_LEDGER=PASS")
end

main()
