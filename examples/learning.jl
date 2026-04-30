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
const min_height =  20.0 # minimum height for simulation to be considered valid
const max_height = 600.0 # maximum height for simulation to be considered valid

using ControlPlots, KiteControllers, LinearAlgebra, NonlinearSolve
import JLD2

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
function residual(corr_vec=nothing; sim_time=nothing)
    global scc
    l_in = 0
    if ! isnothing(corr_vec) 
        l_in=length(corr_vec)
    end
    set = deepcopy(KiteControllers.se(PROJECT))
    if isnothing(sim_time)
        sim_time = set.sim_time
    end
    kcu   = KiteModels.KCU(set)
    kps4 = KiteModels.KPS4(kcu)
    kps4.wm.v_min = 0.1
    wcs = WCSettings(dt = 1/set.sample_freq); update(wcs)
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
            #
            local t_sim = 0.0
            try
                t_sim = @elapsed KiteModels.next_step!(kps4, integrator; set_speed=v_ro, dt=dt)
            catch e
                @warn "Simulation crashed at t=$(round(i*dt, digits=1)) s: $e"
                break
            end
            sys_state = KiteModels.SysState(kps4)
            on_new_systate(ssc, sys_state)
            e_mech += (sys_state.winch_force[1] * sys_state.v_reelout[1])/3600*dt
            sys_state.e_mech = e_mech
            sys_state.sys_state = Int16(ssc.fpp._state)
            sys_state.var_01 = ssc.fpp.fpca.cycle
            sys_state.var_02 = ssc.fpp.fpca.fig8
            if i > 10
                sys_state.t_sim = t_sim*1000
            end
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
        end
        error
    end

    on_parking(ssc)
    saved_use_turbulence = set.use_turbulence
    set.use_turbulence = 0.0
    integrator = try
        KiteModels.init!(kps4; delta=set.delta, stiffness_factor=set.stiffness_factor)
    finally
        set.use_turbulence = saved_use_turbulence
    end
    sim_error = simulate(integrator)
    on_stop(ssc)
    if sim_error.code != NoError
        @warn "Simulation ended with error: $(sim_error.message). Skipping result."
        return l_in > 0 ? fill(1000.0, l_in) : Float64[]
    end
    KiteControllers.save_log(logger, "tmp")
    lg = KiteControllers.load_log("tmp")
    ob = test_ob(lg, false)
    test_ob(lg, true)
    # debug: show what the log contains
    sl = lg.syslog
    println("DEBUG: sim duration = $(sl.time[end]) s")
    println("DEBUG: max cycle (var_01) = $(maximum(sl.var_01))")
    println("DEBUG: max fig8  (var_02) = $(maximum(sl.var_02))")
    unique_states = sort(unique(sl.sys_state))
    println("DEBUG: sys_states seen = $unique_states")
    n_cycle2 = count(sl.var_01 .== 2 .&& sl.sys_state .∈ Ref([6, 8]))
    println("DEBUG: steps with cycle==2 and sys_state in (6,8) = $n_cycle2")
    println("DEBUG: length(ob.corr_vec) = $(length(ob.corr_vec))")
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
        @info "Plotting last simulation log from output/last_sim_log.jld2"
    else
        lg = KiteControllers.load_log("tmp")
        @info "Plotting current simulation log from tmp.jld2"
    end
    sl = lg.syslog
    fig_name = last_sim ? "azimuth_elevation_last" : "azimuth_elevation"
    display(ControlPlots.plotx(sl.time, rad2deg.(sl.azimuth), rad2deg.(sl.elevation);
            ylabels=["azimuth [°]", "elevation [°]"],
            xlabel="time [s]",
            fig=fig_name))
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
        KiteControllers.save_corr(corr_vec)
    end
    initial = FPPSettings(true).corr_vec
    if norm(initial) > 50.0
        @warn "Loaded corr_vec has large norm $(norm(initial)), resetting to zeros."
        initial = zeros(length(initial))
    end
    best_corr_vec = deepcopy(initial)
    best_norm = Inf
    j = 0
    for i in 1:max_iter
        res = residual(initial)
        println("i: $(i), norm: $(norm(res))")
        crashed = length(res) > 0 && res[1] == 1000.0
        if ! crashed
            common_size=min(length(initial), length(res))
            for i = 1:common_size
                if best_norm > 5
                    initial[i] += 0.5 * res[i]
                elseif best_norm > 2.5
                    initial[i] += 0.25*res[i]
                else
                    initial[i] += 0.125*res[i]
                end
            end
        end
        if best_norm > norm(res) && ! crashed
            best_norm = norm(res)
            best_corr_vec = deepcopy(initial)
            j = 0
            println("j: $(j), best_norm= $best_norm")
        else
            j+=1
            println("j: $j")
        end
        if norm(res) < norm_tol
            println("Converged successfully using $i iterations!")
            break
        end
        if j > 4
            println("Convergence failed!")
            println("Best norm: $best_norm")
            break
        end
    end
    if best_norm < Inf
        KiteControllers.save_corr(best_corr_vec)
    else
        @warn "Training produced no valid result. corr_vec.jld2 not updated."
    end
    best_corr_vec
end

println("Available functions: plot(), train(), residual()")
