# activate the test environment if needed
using Pkg
if dirname(Pkg.project().path) != @__DIR__
    Pkg.activate(@__DIR__)
end
using Test, KiteControllers, KiteModels, KiteUtils

# Check that the initial steady state can be found for the settings used by the examples in examples/menu.jl. The steady-state solver is sensitive to small
# numerical differences (e.g. between Julia versions), so these cases are tested explicitly.
# Turbulence is switched off, as the examples also do during init!.

const STEADY_STATE_DATA_PATH = joinpath(dirname(@__DIR__), "data")

# Load the settings of a project and apply the modifications an example makes before init!
function steady_state_settings(project; kwargs...)
    set = deepcopy(load_settings(project))
    set.use_turbulence = 0.0
    for (key, value) in kwargs
        setproperty!(set, key, value)
    end
    set
end

# Run init! and return the integrator; fail if a warning is logged (solver did not converge)
function init_without_warnings(kps)
    @test_logs min_level=Base.CoreLogging.Warn KiteModels.init!(kps)
end

saved_data_path = get_data_path()
saved_project = KiteUtils.PROJECT
set_data_path(STEADY_STATE_DATA_PATH)
try
    # autopilot.jl and batch_pilot.jl: all projects
    @testset "Steady state, project $project" for project in
            sort(filter(f -> endswith(f, ".yml"), readdir(STEADY_STATE_DATA_PATH)))
        set = steady_state_settings(project)
        kps4 = KPS4(KCU(set))
        kps4.wm.v_min = 0.15
        integrator = init_without_warnings(kps4)
        @test !isnothing(integrator)
        @test calc_height(kps4) > 0
    end

    # the other examples of the menu, all based on system.yaml
    examples = [
        # name              settings modifications                            model
        ("joystick",         (;),                                               KPS4),
        ("minipilot",        (;),                                               KPS4),
        ("minipilot_12",     (segments=12,),                                    KPS4),
        ("parking_1p",       (abs_tol=0.00006, rel_tol=0.0001, v_wind=6.5),     KPS3),
        ("parking_4p",       (abs_tol=0.00006, rel_tol=0.0001, v_wind=10.0),    KPS4),
        ("parking_wind_dir", (abs_tol=0.00006, rel_tol=0.0001, sample_freq=20), KPS4),
    ]
    @testset "Steady state, example $name" for (name, mods, Model) in examples
        set = steady_state_settings("system.yaml"; mods...)
        kps = Model(KCU(set))
        integrator = init_without_warnings(kps)
        @test !isnothing(integrator)
        @test calc_height(kps) > 0
    end
finally
    set_data_path(saved_data_path)
    KiteUtils.PROJECT = saved_project
end
nothing
