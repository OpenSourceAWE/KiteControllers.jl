# Fly the same power cycles twice, with the Julia AsyncMachine and with the MatlabMachine (the same
# model, implemented in Matlab and linearized within each time step), and compare the results.
# Without turbulence, so that both runs are deterministic. Needs a Matlab installation.
#
# Usage: julia --project=examples/matlab examples/matlab/compare_full_cycle.jl [project.yml ...]
# without projects, system.yaml is used. When included, the projects are taken from the global
# PROJECTS, if defined.
using Pkg
if dirname(Pkg.project().path) != @__DIR__
    Pkg.activate(@__DIR__)
end
using MATLAB, KiteControllers, KiteModels, KiteUtils, Statistics, Printf

# the following values can be changed to match your interest
MAX_TIME = 460.0  # simulation time [s]
if !@isdefined(PROJECTS)
    PROJECTS = isempty(ARGS) ? ["system.yaml"] : ARGS
end
# end of user parameter section #

matlab_dir = @__DIR__
mat"addpath($matlab_dir)"
set_data_path(joinpath(@__DIR__, "..", "..", "data"))

"""
    fly(winch_model, project; max_time=MAX_TIME)

Simulate with the autopilot, as examples/autopilot.jl does, but without viewer and turbulence.
Returns a named tuple with the time series and the time per step.
"""
function fly(winch_model, project; max_time=MAX_TIME)
    set = deepcopy(load_settings(project))
    set.winch_model = winch_model
    set.use_turbulence = 0.0
    dt = 1/set.sample_freq
    kcu  = KCU(set)
    kps4 = KPS4(kcu)
    kps4.wm.v_min = 0.1
    wcs  = WCSettings(true; dt)
    fcs  = FPCSettings(true; dt)
    fpps = FPPSettings(true)
    u_d0 = 0.01 * set.depower_offset
    u_d  = 0.01 * set.depowers[1]
    ssc  = SystemStateControl(wcs, fcs, fpps; u_d0, u_d, v_wind=set.v_wind)
    on_parking(ssc)
    integrator = KiteModels.init!(kps4; trim=true)
    isnothing(integrator) && error("Could not find the initial steady state.")
    sys_state = SysState(kps4)
    on_new_systate(ssc, sys_state)

    steps = Int(round(max_time/dt))
    time    = zeros(steps)
    force   = zeros(steps)
    v_ro    = zeros(steps)
    length_ = zeros(steps)
    state   = zeros(Int, steps)
    t_step  = zeros(steps)
    e_mech  = 0.0
    for i in 1:steps
        if i > 100
            dp = max(KiteControllers.get_depower(ssc), 0.22)
            heading  = calc_heading(kps4; neg_azimuth=true, one_point=false)
            azimuth  = -calc_azimuth(kps4)
            steering = -calc_steering(ssc; heading, azimuth)
            set_depower_steering(kps4.kcu, dp, steering)
        end
        i == 200 && on_autopilot(ssc)
        v_set = calc_v_set(ssc)
        t_step[i] = @elapsed KiteModels.next_step!(kps4, integrator; set_speed=v_set, dt)
        KiteModels.update_sys_state!(sys_state, kps4)
        on_new_systate(ssc, sys_state)
        e_mech += sys_state.winch_force[1] * sys_state.v_reelout[1] / 3600 * dt
        time[i]    = i * dt
        force[i]   = sys_state.winch_force[1]
        v_ro[i]    = sys_state.v_reelout[1]
        length_[i] = sys_state.l_tether[1]
        state[i]   = Int(ssc.fpp._state)
    end
    (; time, force, v_ro, length=length_, state, t_step, e_mech, cycles=ssc.fpp.fpca.cycle)
end

rel(a, b) = (a - b) / abs(b) * 100

"""
    compare(project)

Fly with both winch models and print the comparison.
"""
function compare(project)
    println("\n$project: flying with the AsyncMachine (Julia)...")
    ref = fly("AsyncMachine", project)
    println("$project: flying with the MatlabMachine (Matlab)...")
    mat = fly("MatlabMachine", project)

    skip = Int(round(10 / (ref.time[2] - ref.time[1])))  # ignore the first 10 s (compilation)
    @printf("\n%-28s %14s %14s %10s\n", project, "AsyncMachine", "MatlabMachine", "diff")
    @printf("%-28s %14.1f %14.1f %9.3f %%\n", "energy e_mech [Wh]", ref.e_mech, mat.e_mech,
            rel(mat.e_mech, ref.e_mech))
    @printf("%-28s %14d %14d\n", "cycles", ref.cycles, mat.cycles)
    @printf("%-28s %14.1f %14.1f %9.3f %%\n", "mean force [N]", mean(ref.force), mean(mat.force),
            rel(mean(mat.force), mean(ref.force)))
    @printf("%-28s %14.1f %14.1f %9.3f %%\n", "max force [N]", maximum(ref.force), maximum(mat.force),
            rel(maximum(mat.force), maximum(ref.force)))
    @printf("%-28s %14.3f %14.3f\n", "min reel-out speed [m/s]", minimum(ref.v_ro), minimum(mat.v_ro))
    @printf("%-28s %14.3f %14.3f\n", "max reel-out speed [m/s]", maximum(ref.v_ro), maximum(mat.v_ro))
    for (name, t) in (("AsyncMachine", ref.t_step), ("MatlabMachine", mat.t_step))
        t = t[skip:end] .* 1e3
        @printf("time per step, %-14s median %.3f ms  p99 %.3f ms  max %.3f ms\n",
                name, median(t), quantile(t, 0.99), maximum(t))
    end
    # the difference of the time series, until the first change of the state of the flight path
    # planner that happens at a different time step
    first_diff = findfirst(ref.state .!= mat.state)
    n = isnothing(first_diff) ? length(ref.time) : max(first_diff - 1, 1)
    @printf("identical sequence of the flight path planner states until t = %.2f s\n", ref.time[n])
    @printf("until then: max |Δforce| = %.1f N, max |Δv_ro| = %.4f m/s, max |Δlength| = %.4f m\n",
            maximum(abs.(mat.force[1:n] .- ref.force[1:n])),
            maximum(abs.(mat.v_ro[1:n] .- ref.v_ro[1:n])),
            maximum(abs.(mat.length[1:n] .- ref.length[1:n])))
end

for project in PROJECTS
    compare(project)
end
nothing
