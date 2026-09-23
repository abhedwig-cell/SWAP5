using Ribasim
import BasicModelInterface as BMI

const DAY = 86400.0
const AREA = 1_000_000.0
const REF_TARGETS = [18000.0, 21600.0, 36000.0, 43200.0, 54000.0, 64800.0, 72000.0, 86400.0]
const PRODUCT_TARGETS = [21600.0, 43200.0, 64800.0, 86400.0]
const EXPECTED_ALLOC_TIMES = [0.0, 18000.0, 36000.0, 54000.0, 72000.0]
const EXPECTED_NAIVE_ALLOC_TIMES = [0.0]
const VOLUME_TOL = 1.0e-8
const LEVEL_TOL = 1.0e-10
const TIME_TOL = 1.0e-6
const MASS_TOL = 0.05
const MIN_SEPARATION = 1.0

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function parse_targets(text::AbstractString)
    isempty(strip(text)) && error("empty scheduler target list")
    return parse.(Float64, split(text, ","))
end

function node_id(model, typ::Symbol, id::Int)
    return Ribasim.NodeID(typ, id, model.integrator.p.p_independent)
end

function snapshot(model, endpoint::Float64)
    root_id = node_id(model, :UserDemand, 3)
    external_id = node_id(model, :UserDemand, 4)
    basin_id = node_id(model, :Basin, 2)
    cumulative = BMI.get_value_ptr(model, "user_demand.cumulative_inflow")
    levels = BMI.get_value_ptr(model, "basin.level")
    return (
        endpoint = endpoint,
        root = cumulative[root_id.idx],
        external = cumulative[external_id.idx],
        level = levels[basin_id.idx],
    )
end

function allocation_times(model)
    allocation = model.integrator.p.p_independent.allocation
    return sort(unique(Float64(d.time) for d in allocation.record_demand))
end

function check_times(observed, expected, label)
    require(length(observed) == length(expected),
        "$label allocation count $(length(observed)) != $(length(expected)); observed=$observed")
    for (a,b) in zip(observed, expected)
        require(isapprox(a,b; atol=TIME_TOL, rtol=0.0), "$label allocation time $a != $b")
    end
end

function run_route(path::AbstractString, targets)
    model = BMI.initialize(Ribasim.Model, path)
    states = NamedTuple[]
    try
        for target in targets
            BMI.update_until(model, target)
            require(isapprox(BMI.get_current_time(model), target; atol=TIME_TOL, rtol=0.0),
                "BMI endpoint mismatch at $target")
            push!(states, snapshot(model, target))
        end
        return (states=states, allocation=allocation_times(model))
    finally
        BMI.finalize(model)
    end
end

function compare_routes(a, b)
    require(length(a.states) == length(b.states), "route state count mismatch")
    for (x,y) in zip(a.states,b.states)
        require(isapprox(x.endpoint,y.endpoint; atol=TIME_TOL,rtol=0.0), "route endpoint mismatch")
        require(isapprox(x.root,y.root; atol=VOLUME_TOL,rtol=0.0), "route root mismatch at $(x.endpoint)")
        require(isapprox(x.external,y.external; atol=VOLUME_TOL,rtol=0.0), "route external mismatch at $(x.endpoint)")
        require(isapprox(x.level,y.level; atol=LEVEL_TOL,rtol=0.0), "route level mismatch at $(x.endpoint)")
    end
    check_times(a.allocation,b.allocation,"route equivalence")
end

function final_ledger(route, label)
    final = last(route.states)
    total = final.root + final.external
    storage_gain = AREA * (final.level - 1.0)
    require(isapprox(total + storage_gain, 32.0; atol=MASS_TOL, rtol=0.0),
        "$label physical ledger does not close: total=$total storage=$storage_gain")
    return (total=total, storage_gain=storage_gain, level=final.level)
end

function main()
    length(ARGS) == 2 || error("usage: rm12_real_ribasim_scheduler.jl <ribasim.toml> <comma-separated-scheduler-targets>")
    path = abspath(ARGS[1])
    scheduler_targets = parse_targets(ARGS[2])
    require(length(scheduler_targets) == length(REF_TARGETS), "scheduler target count")
    for (a,b) in zip(scheduler_targets,REF_TARGETS)
        require(isapprox(a,b; atol=TIME_TOL,rtol=0.0), "production scheduler target $a != frozen $b")
    end

    scheduler = run_route(path,scheduler_targets)
    reference = run_route(path,REF_TARGETS)
    naive = run_route(path,PRODUCT_TARGETS)

    compare_routes(scheduler,reference)
    check_times(scheduler.allocation,EXPECTED_ALLOC_TIMES,"scheduler")
    check_times(reference.allocation,EXPECTED_ALLOC_TIMES,"reference")
    check_times(naive.allocation,EXPECTED_NAIVE_ALLOC_TIMES,"naive")

    sched_ledger = final_ledger(scheduler,"scheduler")
    naive_ledger = final_ledger(naive,"naive")
    separation = sched_ledger.total - naive_ledger.total
    require(abs(separation) > MIN_SEPARATION,
        "scheduler/naive day-end delivery separation too small: $separation")

    println("RM12_SCHEDULER_TARGETS=$(scheduler_targets)")
    println("RM12_SCHEDULER_ALLOCATION_TIMES=$(scheduler.allocation)")
    println("RM12_NAIVE_ALLOCATION_TIMES=$(naive.allocation)")
    println("RM12_SCHEDULER_FINAL_ROOT_M3=$(last(scheduler.states).root)")
    println("RM12_SCHEDULER_FINAL_EXTERNAL_M3=$(last(scheduler.states).external)")
    println("RM12_SCHEDULER_FINAL_TOTAL_M3=$(sched_ledger.total)")
    println("RM12_SCHEDULER_FINAL_LEVEL_M=$(sched_ledger.level)")
    println("RM12_SCHEDULER_STORAGE_GAIN_M3=$(sched_ledger.storage_gain)")
    println("RM12_NAIVE_FINAL_TOTAL_M3=$(naive_ledger.total)")
    println("RM12_DAY_END_TOTAL_SEPARATION_M3=$separation")
    println("RM12_SCHEDULER_REFERENCE_TRAJECTORY_EQUIVALENCE=PASS")
    println("RM12_NONCOMMENSURATE_ALLOCATION_RECORDS=PASS")
    println("RM12_NAIVE_H10_ALIASING_CONTROL=PASS")
    println("RM12_MASS_LEDGER=PASS")
    println("RM12 REAL RIBASIM SCHEDULER TRAJECTORY GATE PASS")
end

main()
