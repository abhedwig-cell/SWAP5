using Ribasim
import BasicModelInterface as BMI

const DAY = 86400.0
const DT_DAY = 1.0e-4
const DURATION_SECONDS = 8.64
const AREA_M2 = 1.0
const LEVEL_TOL = 1.0e-8
const STORAGE_TOL = 1.0e-8
const DISCHARGE_TOL = 1.0e-8
const MASS_TOL = 1.0e-8
const ORACLE_MASS_TOL_CM = 1.0e-12
const TIME_TOL = 1.0e-8

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
    require([r.id for r in rows] == [
        "C0_NO_DISCHARGE",
        "C1_MODERATE_DISCHARGE",
        "C2_HIGH_DISCHARGE",
    ], "oracle case set drift")
    return rows
end

function basin_level(model)
    values = BMI.get_value_ptr(model, "basin.level")
    require(length(values) == 1, "Q1A requires exactly one Basin")
    return Float64(values[1])
end

function run_case(model_root::AbstractString, case)
    path = joinpath(model_root, case.id, "ribasim.toml")
    model = BMI.initialize(Ribasim.Model, path)
    try
        initial_level = basin_level(model)
        require(isapprox(initial_level, case.initial_level_cm / 100.0; atol=1.0e-12, rtol=0.0),
            "$(case.id) initial level drift: $initial_level")
        BMI.update_until(model, DURATION_SECONDS)
        require(isapprox(BMI.get_current_time(model), DURATION_SECONDS; atol=TIME_TOL, rtol=0.0),
            "$(case.id) endpoint mismatch")

        final_level = basin_level(model)
        initial_storage_m3 = case.initial_storage_cm * 0.01
        final_storage_m3 = final_level + 1.0
        input_m3 = case.drainage_cm_day * 0.01 * AREA_M2 * DT_DAY
        inferred_discharge_m3 = initial_storage_m3 + input_m3 - final_storage_m3

        oracle_level_m = case.final_level_cm / 100.0
        oracle_storage_m3 = case.final_storage_cm * 0.01
        oracle_discharge_m3 = case.discharge_cm_day * DT_DAY * 0.01
        ribasim_mass_residual = final_storage_m3 - initial_storage_m3 - input_m3 + inferred_discharge_m3

        require(abs(case.mass_residual_cm) <= ORACLE_MASS_TOL_CM,
            "$(case.id) oracle mass residual $(case.mass_residual_cm)")
        require(abs(final_level - oracle_level_m) <= LEVEL_TOL,
            "$(case.id) level mismatch ribasim=$final_level oracle=$oracle_level_m")
        require(abs(final_storage_m3 - oracle_storage_m3) <= STORAGE_TOL,
            "$(case.id) storage mismatch ribasim=$final_storage_m3 oracle=$oracle_storage_m3")
        require(abs(inferred_discharge_m3 - oracle_discharge_m3) <= DISCHARGE_TOL,
            "$(case.id) discharge mismatch ribasim=$inferred_discharge_m3 oracle=$oracle_discharge_m3")
        require(abs(ribasim_mass_residual) <= MASS_TOL,
            "$(case.id) Ribasim ledger residual $ribasim_mass_residual")

        if case.id == "C0_NO_DISCHARGE"
            require(abs(inferred_discharge_m3) <= DISCHARGE_TOL,
                "C0 unexpectedly discharged $inferred_discharge_m3")
        else
            require(inferred_discharge_m3 > 0.0,
                "$(case.id) did not discharge")
        end

        println("SW_RIB_SWM01_Q1A_CASE=$(case.id)")
        println("  FINAL_LEVEL_RIBASIM_M=$final_level")
        println("  FINAL_LEVEL_ORACLE_M=$oracle_level_m")
        println("  FINAL_STORAGE_RIBASIM_M3=$final_storage_m3")
        println("  FINAL_STORAGE_ORACLE_M3=$oracle_storage_m3")
        println("  DISCHARGE_RIBASIM_INFERRED_M3=$inferred_discharge_m3")
        println("  DISCHARGE_ORACLE_M3=$oracle_discharge_m3")
        println("  MASS_RESIDUAL_M3=$ribasim_mass_residual")
        println("SW_RIB_SWM01_Q1A_CASE_PASS=$(case.id)")
    finally
        BMI.finalize(model)
    end
end

function main()
    length(ARGS) == 2 || error("usage: q1a_real_ribasim_equivalence.jl <oracle.csv> <model-root>")
    rows = parse_oracle(abspath(ARGS[1]))
    root = abspath(ARGS[2])
    for case in rows
        run_case(root, case)
    end
    println("SW_RIB_SWM01_Q1A_REAL_RIBASIM_EXTERNAL_OWNER_EQUIVALENCE=PASS")
end

main()
