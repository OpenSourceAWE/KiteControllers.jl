## this script provides the main functions 
## - residual()
## - train()
## The train() function trains the flight path planner for a specific 
## wind speed and kite. It creates the file "data/corr_vec.jld2".

# activate the test environment if needed
using Pkg
if ! ("ControlPlots" ∈ keys(Pkg.project().dependencies))
    Pkg.activate(@__DIR__)
end
using KiteControllers, KiteModels, YAML
using KiteUtils: load_settings

function get_use_turbulence(project::String)
    config_file = joinpath(get_data_path(), project)
    dict = YAML.load_file(config_file)
    overwrite = get(dict, "overwrite", nothing)
    isnothing(overwrite) && return nothing
    result = get(overwrite, "use_turbulence", nothing)
    isnothing(result) && return nothing
    return Float64(result)
end

function read_project()
    config_file = joinpath(get_data_path(), "gui.yaml")
    dict = YAML.load_file(config_file)
    dict["gui"]["project"]
end

PROJECT=read_project()

@enum SimError begin
    NoError
    TooLow
    TooHigh
    VelocityTooHigh
    VelocityTooLow
end

struct SimulationError
    code::SimError
    message::String
end

SimulationError() = SimulationError(NoError, "")

const tolerance  =   1.1 # allow 10% tolerance for velocity limits
const min_height =  10.0 # minimum height for simulation to be considered valid
const max_height = 600.0 # maximum height for simulation to be considered valid
MAX_NORM = 100.0         # maximum allowed norm for corr_vec

using ControlPlots, KiteControllers, LinearAlgebra, NonlinearSolve
import JLD2

ssc = nothing

function test_ob(lg, plot=true)
    ob = KiteObserver()
    KiteControllers.observe!(ob, lg)
    if plot
        plotxy(ob.fig8, ob.elevation, xlabel="fig8", ylabel="elevation")
    else
        ob
    end
end

# run a simulation using a correction vector, return a log object
function residual(corr_vec=nothing)
    global ssc
    l_in = 0
    if ! isnothing(corr_vec) 
        l_in=length(corr_vec)
    end
    set = deepcopy(load_settings(PROJECT))
    use_turbulence = get_use_turbulence(PROJECT)
    isnothing(use_turbulence) || (set.use_turbulence = use_turbulence)
    sim_time = set.sim_time
    kcu   = KiteModels.KCU(set)
    kps4 = KiteModels.KPS4(kcu)
    kps4.wm.v_min = 0.1
    KiteUtils.PROJECT = PROJECT
    wcs = WCSettings(true; dt = 1/set.sample_freq)
    wcs.dt = 1/set.sample_freq
    fcs = FPCSettings(true, dt=wcs.dt)
    fpps = FPPSettings(true)
    u_d0 = 0.01 * set.depower_offset
    u_d  = 0.01 * set.depowers[1]
    ssc = SystemStateControl(wcs, fcs, fpps; u_d0, u_d, v_wind=set.v_wind)
    if ! isnothing(corr_vec)
        ssc.fpp.corr_vec = corr_vec
    end
    dt = wcs.dt
    steps = Int64(sim_time/dt)
    particles = set.segments + 5
    logger = KiteControllers.Logger(particles, steps)

    function simulate(integrator)
        i = 1
        error = SimulationError()
        sys_state = KiteModels.SysState(kps4)
        sys_state.e_mech = 0
        e_mech = 0
        sys_state.sys_state = Int16(ssc.fpp._state)
        on_new_systate(ssc, sys_state)
        KiteControllers.log!(logger, sys_state)
        while true
            if i > 100
                dp = KiteControllers.get_depower(ssc)
                if dp < 0.22 dp = 0.22 end
                heading = calc_heading(kps4; neg_azimuth=true, one_point=false)
                ssc.sys_state.heading = heading
                ssc.sys_state.azimuth = -calc_azimuth(kps4)
                local steering
                try
                    steering = -calc_steering(ssc)
                catch e
                    @warn "calc_steering crashed at t=$(round(i*dt, digits=1)) s: $e"
                    break
                end
                KiteModels.set_depower_steering(kps4.kcu, dp, steering)
            end
            if i == 200
                on_autopilot(ssc)
            end
            # execute winch controller
            local v_ro
            try
                v_ro = calc_v_set(ssc)
            catch e
                @warn "calc_v_set crashed at t=$(round(i*dt, digits=1)) s: $e"
                break
            end
            try
                KiteModels.next_step!(kps4, integrator; set_speed=v_ro, dt=dt)
            catch e
                @warn "Simulation crashed at t=$(round(i*dt, digits=1)) s: $e"
                break
            end
            sys_state = KiteModels.SysState(kps4)
            on_new_systate(ssc, sys_state)
            e_mech += (sys_state.winch_force[1] * sys_state.v_reelout[1])/3600*dt
            sys_state.e_mech = e_mech
            sys_state.sys_state = Int16(ssc.fpp._state)
            sys_state.cycle = ssc.fpp.fpca.cycle
            sys_state.fig_8 = ssc.fpp.fpca.fig8
            KiteControllers.log!(logger, sys_state)
            if i > 200
                if sys_state.Z[end] < min_height
                    error = SimulationError(TooLow, "Height $(round(sys_state.Z[end], digits=2)) m is below minimum $(min_height) m")
                    break
                end
                if sys_state.Z[end] > max_height
                    error = SimulationError(TooHigh, "Height $(round(sys_state.Z[end], digits=2)) m exceeds maximum $(max_height) m")
                    break
                end
                if sys_state.v_reelout[1] > tolerance * set.v_ro_max
                    error = SimulationError(VelocityTooHigh, "Reel-out speed $(round(sys_state.v_reelout[1], digits=3)) m/s exceeds limit $(round(tolerance * set.v_ro_max, digits=3)) m/s")
                    break
                end
                if sys_state.v_reelout[1] < tolerance * set.v_ro_min
                    error = SimulationError(VelocityTooLow, "Reel-out speed $(round(sys_state.v_reelout[1], digits=3)) m/s is below limit $(round(tolerance * set.v_ro_min, digits=3)) m/s")
                    break
                end
            end
            i += 1
            if i*dt > sim_time
                break 
            end
            if ssc.fpp.fpca.cycle >= 3
                break
            end
        end
        error
    end

    on_parking(ssc)
    integrator = KiteModels.init!(kps4; delta=set.delta, stiffness_factor=set.stiffness_factor)
    sim_error = simulate(integrator)
    on_stop(ssc)
    if sim_error.code != NoError
        @warn "Simulation ended with error: $(sim_error.message). Skipping result."
        return l_in > 0 ? fill(1000.0, l_in) : Float64[]
    end
    KiteControllers.save_log(logger, "tmp"; path="output")
    lg = KiteControllers.load_log("tmp"; path="output")
    ob = test_ob(lg, false)
    test_ob(lg, true)
    println("\n --> norm: ", norm(ob.corr_vec), "\n")
    l_out = length(ob.corr_vec)
    println("l_out: $l_out")
    if l_out == 0
        @warn "No flight path data collected (simulation may have crashed early). Skipping update."
        return l_in > 0 ? fill(1000.0, l_in) : Float64[]
    end
    if l_out < l_in
        for _ in 1:(l_in-l_out)
            push!(ob.corr_vec, 0)
        end
    end
    if l_in > 0
        return ob.corr_vec[begin:l_in]
    end
    ob.corr_vec
end

function plot(last_sim=false)
    if last_sim
        lg = KiteControllers.load_log("last_sim_log"; path="output")
        @info "Plotting last simulation log from output/last_sim_log.arrow"
    else
        lg = KiteControllers.load_log("tmp"; path="output")
        @info "Plotting current simulation log from output/tmp.arrow"
    end
    sl = lg.syslog
    fig_name = last_sim ? "azimuth_elevation_last" : "azimuth_elevation"
    display(ControlPlots.plotx(sl.time, rad2deg.(sl.azimuth), rad2deg.(sl.elevation);
            ylabels=["azimuth [°]", "elevation [°]"],
            xlabel="time [s]",
            fig=fig_name))
    nothing
end

function observe()
    lg = KiteControllers.load_log("tmp"; path="output")
    ob = KiteObserver()
    KiteControllers.observe!(ob, lg)
    println("corr_vec (length=$(length(ob.corr_vec))):")
    for v in ob.corr_vec
        println("  ", v)
    end
    nothing
end

function train(use_last=true; max_iter=40, norm_tol=1.0)
    local corr_vec
    if ! use_last
        try
            log = load_log("uncorrected")
            ob = KiteObserver()
            observe!(ob, log)
            corr_vec=ob.corr_vec
        catch
            corr_vec=residual()
        end
        if isempty(corr_vec)
            @warn "residual() returned an empty vector; skipping initial save_corr."
        else
            KiteControllers.save_corr(corr_vec)
        end
    end
    initial = FPPSettings(true).corr_vec
    if norm(initial) > MAX_NORM
        @warn "Loaded corr_vec has large norm $(norm(initial)), resetting to zeros."
        initial = zeros(length(initial))
    end
    if norm(initial) < 1e-6
        @info "Loaded corr_vec is all zeros; using struct defaults as starting point."
        initial = FPPSettings().corr_vec
    end
    best_corr_vec = deepcopy(initial)
    best_norm = Inf
    j = 0             # counts consecutive successful-but-no-improvement runs
    j_crash = 0       # counts consecutive crashes (safety limit)
    step_factor = 1.0
    last_res = zeros(length(initial))  # last non-crashed residual
    correction_applied = false
    for i in 1:max_iter
        res = residual(initial)
        println("i: $(i), norm: $(norm(res))")
        crashed = length(res) > 0 && res[1] == 1000.0
        if !crashed && norm(res) < norm_tol
            println("Converged successfully using $i iterations!")
            best_corr_vec = deepcopy(initial)
            best_norm = norm(res)
            correction_applied = true
            break
        end
        if crashed
            # Roll back to the last known-good vector, halve the step, and apply
            # the reduced step immediately using the last valid residual.
            # Crashes do NOT count toward j — they are handled by step reduction.
            j_crash += 1
            step_factor /= 2.0
            println("Crash detected: rolling back to best_corr_vec, step_factor= $step_factor (j_crash=$j_crash)")
            initial = deepcopy(best_corr_vec)
            common_size = min(length(initial), length(last_res))
            for k = 1:common_size
                if best_norm > 5
                    initial[k] += step_factor * 0.5 * last_res[k]
                elseif best_norm > 2.5
                    initial[k] += step_factor * 0.25 * last_res[k]
                else
                    initial[k] += step_factor * 0.125 * last_res[k]
                end
            end
            if j_crash > 8
                println("Too many consecutive crashes; giving up.")
                break
            end
        else
            j_crash = 0
            last_res = res
            # Save best BEFORE updating initial, so best_corr_vec is the vector
            # that actually produced best_norm (not the next-step candidate).
            if best_norm > norm(res)
                best_norm = norm(res)
                best_corr_vec = deepcopy(initial)
                # Ramp step_factor back up gradually (×2 per success, capped at 1.0)
                # rather than jumping straight back to 1.0, to avoid immediate re-crash.
                step_factor = min(step_factor * 2.0, 1.0)
                j = 0
                println("j: $(j), best_norm= $best_norm, step_factor= $step_factor")
            else
                j += 1
                println("j: $j")
            end
            common_size = min(length(initial), length(res))
            for k = 1:common_size
                if best_norm > 5
                    initial[k] += step_factor * 0.5 * res[k]
                elseif best_norm > 2.5
                    initial[k] += step_factor * 0.25 * res[k]
                else
                    initial[k] += step_factor * 0.125 * res[k]
                end
            end
            correction_applied = true
        end
        if j > 4
            println("Convergence failed!")
            println("Best norm: $best_norm")
            break
        end
    end
    last_nonzero = something(findlast(!iszero, best_corr_vec), length(best_corr_vec))
    best_corr_vec = best_corr_vec[1:last_nonzero]
    if best_norm < Inf && correction_applied
        KiteControllers.save_corr(best_corr_vec)
    elseif !correction_applied && best_norm == Inf
        @warn "All simulations crashed; no corrections could be applied. Check project settings."
    elseif !correction_applied
        @info "Already converged before applying any correction; yaml file not updated."
    else
        @warn "Training produced no valid result. corr_vec.jld2 not updated."
    end
    best_corr_vec
end

function plot_batch()
    lg = KiteControllers.load_log("batch-hydra20_600_TI0"; path="output")
    @info "Plotting batch log from output/batch-hydra20_600_TI0.arrow"
    sl = lg.syslog
    display(ControlPlots.plotx(sl.time, rad2deg.(sl.azimuth), rad2deg.(sl.elevation);
            ylabels=["azimuth [°]", "elevation [°]"],
            xlabel="time [s]",
            fig="azimuth_elevation_batch"))
    nothing
end

println("Available functions: plot(), plot_batch(), observe(), train(), residual()")
