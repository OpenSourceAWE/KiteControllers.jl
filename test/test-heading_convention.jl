# activate the test environment if needed
using Pkg
if dirname(Pkg.project().path) != @__DIR__
    Pkg.activate(@__DIR__)
end
using Test, KiteControllers, KiteModels
using KiteControllers: on_new_data, UPPER_TURN, LOW_RIGHT, LOW_TURN, LOW_LEFT, TURN_LEFT,
                       FLY_RIGHT, TURN_RIGHT, FLY_LEFT, UP_TURN, UP_TURN_LEFT, UP_FLY_UP

function new_planner()
    fcs = FPCSettings(dt=0.05)
    fpps = FPPSettings(log_level=0)
    fpc = FlightPathController(fcs; u_d0=0.01 * se().depower_offset,
                               u_d=0.01 * se().depower)
    FlightPathPlanner(fpps, FlightPathCalculator(fpc, fpps))
end

# state reached from `state` after one planner step at `heading_deg`
function next_state(state, heading_deg)
    fpp = new_planner()
    fpp._state = state
    on_new_data(fpp, 0.25, 150.0, mod2pi(deg2rad(heading_deg)), 100.0)
    fpp._state
end

@testset "controller receives heading and course positive to the right" begin
    fpp = new_planner()
    heading, course = deg2rad(30.0), deg2rad(-40.0)
    on_new_systate(fpp, 0.0, deg2rad(30.0), heading, course, 10.0, 0.25)
    @test fpp.fpca.fpc.psi ≈ heading
    @test fpp.fpca.fpc.chi ≈ course
end

@testset "planner ends each turn at the right-handed heading" begin
    fpps = FPPSettings()
    upper = fpps.heading_upper_turn
    low = fpps.heading_offset_low
    int = fpps.heading_offset_int
    up = fpps.heading_offset_up
    @test next_state(UPPER_TURN, upper + 5) == LOW_RIGHT
    @test next_state(UPPER_TURN, upper - 5) == UPPER_TURN
    @test next_state(UPPER_TURN, 185.0) == UPPER_TURN
    @test next_state(LOW_TURN, 180 - int + 2) == LOW_LEFT
    @test next_state(LOW_TURN, 180 - int - 2) == LOW_TURN
    @test next_state(TURN_LEFT, 180 + low - 2) == FLY_RIGHT
    @test next_state(TURN_LEFT, 180 + low + 2) == TURN_LEFT
    @test next_state(TURN_RIGHT, 180 - low + 2) == FLY_LEFT
    @test next_state(TURN_RIGHT, 180 - low - 2) == TURN_RIGHT
    for state in (UP_TURN, UP_TURN_LEFT), sign in (-1, 1)
        @test next_state(state, sign * (up - 2)) == UP_FLY_UP
        @test next_state(state, sign * (up + 2)) == state
    end
end
