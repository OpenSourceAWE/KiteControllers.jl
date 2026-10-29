# Compare the Matlab implementation of the winch model (async_machine_step.m, used by the
# MatlabMachine of WinchModels.jl) with the Julia AsyncMachine. Needs a Matlab installation.
# Start the Matlab engine before Pkg or Downloads are loaded (KiteUtils loads Pkg): with
# Matlab R2025a, starting it later crashes Julia (segmentation fault). Therefore this environment
# is activated without Pkg.
if dirname(Base.active_project()) != @__DIR__
    Base.set_active_project(joinpath(@__DIR__, "Project.toml"))
end
using MATLAB
matlab_dir = @__DIR__
mat"addpath($matlab_dir)"
using WinchModels, KiteUtils, Statistics, Test
set_data_path(joinpath(@__DIR__, "..", "..", "data"))
set = load_settings("system.yaml")

ext = Base.get_extension(WinchModels, :WinchModelsMATLABExt)

# acceleration of the Julia model for the state of am, without changing it
acc_julia(am, speed, force, use_brake) =
    calc_acceleration(am, speed, force; use_brake, update_state=false)

@testset "MatlabMachine" begin
    @testset "numbers arrive in Matlab unchanged" begin
        x = [0.1, 1/3, -2.5e-17, 1.0e300, 5.0e-324, prevfloat(1.0), NaN, Inf, -Inf]
        eval_string("wm_t = [" * join(ext.mat_num.(x), " ") * "];")
        y = vec(jarray(get_mvariable(:wm_t)))
        @test isequal(y, x)
        eval_string("clear wm_t;")
    end

    @testset "Matlab model equals the Julia AsyncMachine" begin
        mm = MatlabMachine(set)
        n_cases = 0
        for use_brake in (false, true), brake in (false, true),
            last_set_speed in (-4.0, -0.1, 0.0, 0.15, 2.0, 7.5),
            set_speed in (nothing, -6.0, -0.15, 0.0, 0.1, 0.3, 2.2, 9.0),
            speed in (-5.0, -0.5, 0.0, 0.05, 1.9, 6.0),
            force in (0.0, 300.0, 4000.0)

            am = AsyncMachine(set)
            am.brake, am.last_set_speed = brake, last_set_speed
            mm.brake, mm.last_set_speed = brake, last_set_speed
            update_winch_state!(am, set_speed; use_brake)
            update_winch_state!(mm, set_speed; use_brake, speed, force)
            @test mm.brake == am.brake
            @test mm.last_set_speed == am.last_set_speed
            acc = acc_julia(am, speed, force, use_brake)
            @test mm.acc0 ≈ acc rtol=1e-12 atol=1e-12
            # partial derivatives against central differences of the Julia model
            h = 1e-6
            dacc_dv = (acc_julia(am, speed + h, force, use_brake) -
                       acc_julia(am, speed - h, force, use_brake)) / 2h
            dacc_dF = (acc_julia(am, speed, force + 1e-3, use_brake) -
                       acc_julia(am, speed, force - 1e-3, use_brake)) / 2e-3
            @test mm.dacc_dv ≈ dacc_dv rtol=1e-6 atol=1e-6
            @test mm.dacc_dF ≈ dacc_dF rtol=1e-6 atol=1e-9
            # the first order expansion is exact at the point of the linearization
            @test calc_acceleration(mm, speed, force; use_brake, update_state=false) ≈ mm.acc0
            n_cases += 1
        end
        println("compared $n_cases cases")
    end

    @testset "errors of Matlab are reported" begin
        mm = MatlabMachine(set)
        update_winch_state!(mm, 2.0; speed=2.0, force=1000.0)
        eval_string("clear async_machine_step;")  # forget the parameters
        @test_throws ErrorException update_winch_state!(mm, 2.0; speed=2.0, force=1000.0)
        mm.initialized = false  # sends the parameters again
        update_winch_state!(mm, 2.0; speed=2.0, force=1000.0)
        @test mm.initialized
    end

    @testset "time per call" begin
        mm = MatlabMachine(set)
        mm.brake = false
        update_winch_state!(mm, 2.0; use_brake=true, speed=2.0, force=1000.0)
        t = [(@elapsed update_winch_state!(mm, 2.0; use_brake=true, speed=2.0, force=1000.0))
             for _ in 1:500] .* 1e3
        println("update_winch_state!(::MatlabMachine): median $(round(median(t), digits=3)) ms, " *
                "max $(round(maximum(t), digits=3)) ms")
        @test median(t) < 50.0  # less than one time step of 50 ms
    end
end
nothing
