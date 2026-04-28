# activate the test environment if needed
if !@isdefined(KiteControllers)
    import Pkg
    Pkg.activate(@__DIR__)
    using Test, KiteControllers
end

@testset "FlightPathController" begin
    fcs = FPCSettings(dt=0.05)
    fpc = FlightPathController(fcs;  u_d0=0.01 * se().depower_offset, u_d=0.01 * se().depower) 
    on_control_command(fpc)
    phi = 0.0
    beta = 0.0
    psi = 0.0
    chi = 0.0
    omega = 0.0
    v_a = 0.0
    on_est_sysstate(fpc, phi, beta, psi, chi, omega, v_a, u_d=0.236)
    KiteControllers.navigate(fpc)
    psi_dot = 0.0
    KiteControllers.linearize(fpc, psi_dot)
    x = [0, 0]
    KiteControllers.calc_sat1in_sat1out_sat2in_sat2out(fpc, x)
    parking = false
    KiteControllers.calc_steering(fpc, parking)
    turning, value = KiteControllers.get_state(fpc)
    @test ! turning
    @test value == [0.0, 0.0]
end

@testset "FPC_01" begin
    PARKING = false
    fcs = FPCSettings(dt=0.05)
    fcs.dt = 0.02
    fpc = FlightPathController(fcs; u_d0=0.01 * se().depower_offset, u_d=0.01 * se().depower) 
    us = calc_steering(fpc, PARKING)
    @test us == 0.0
end

@testset "testNDI_01" begin
    # test nonlinear dynamic inversion
    fcs = FPCSettings(dt=0.05)
    fcs.dt = 0.02
    fpc = FlightPathController(fcs; u_d0=0.01 * se().depower_offset, u_d=0.01 * se().depower)
    psi_dot = deg2rad(0.0)
    fpc.u_d_prime = 0.2
    fpc.va = 20.0
    fpc.psi = deg2rad(90.0)
    fpc.beta = deg2rad(45.0)
    u_s = KiteControllers.linearize(fpc, psi_dot)
    @test u_s ≈ -0.31541575530041116
end

@testset "FPC_02a" begin
    PARKING = false
    fcs = FPCSettings(dt=0.05)
    fcs.dt = 0.02
    fpc = FlightPathController(fcs; u_d0=0.01 * se().depower_offset, u_d=0.01 * se().depower)
    x = [0.1, 0]
    a,b,c,d,e = KiteControllers.calc_sat1in_sat1out_sat2in_sat2out(fpc, x)
    @test a ≈ 0.0004
    @test b ≈ 0.0004
    @test c ≈ 0.0007137043822911918
    @test d ≈ 0.0007137043822911918
    @test e ≈ 0.5
    x = [0.1, 0.1]
    a,b,c,d,e = KiteControllers.calc_sat1in_sat1out_sat2in_sat2out(fpc, x)
    # println(a,b,c,d,e)    # (0.0012, 0.0012, 0.002141113146873575, 0.002141113146873575, 1.5)
end

@testset "FPC_02" begin
    PARKING = false
    fcs = FPCSettings(dt=0.05)
    fcs.dt = 0.02
    fpc = FlightPathController(fcs; u_d0=0.01 * se().depower_offset, u_d=0.01 * se().depower)
    u_d = 0.24
    va = 24.0
    beta = deg2rad(70.0)
    psi = deg2rad(90.0)
    chi = psi
    omega = 5.0
    phi = 0.0
    on_est_sysstate(fpc, phi, beta, psi, chi, omega, va; u_d=u_d)
    @test fpc.u_d_max ≈ 0.422
    @test fpc.va_av ≈ 24.0
    KiteControllers.on_timer(fpc)
    us = calc_steering(fpc, PARKING)
    @test us == 0.99
end

@testset "FPC_03" begin
     # test navigate method
    fcs = FPCSettings(dt=0.05)
    fcs.dt = 0.02
    fpc = FlightPathController(fcs; u_d0=0.01 * se().depower_offset, u_d=0.01 * se().depower)
    phi_set = deg2rad(0)
    beta_set = deg2rad(50)
    fpc.attractor[1] = phi_set
    fpc.attractor[2] = beta_set
    fpc.phi = deg2rad(-45)
    fpc.beta = deg2rad(45)
    fpc.psi_dot_set = nothing
    KiteControllers.navigate(fpc)
    @test rad2deg(fpc.chi_set) ≈ -64.14299966054402
end

@testset "FPC_04" begin
     # test navigate method with active limit for delta_beta
    fcs = FPCSettings(dt=0.05)
    fcs.dt = 0.02
    fpc = FlightPathController(fcs; u_d0=0.01 * se().depower_offset, u_d=0.01 * se().depower)
    phi_set = deg2rad(0)
    beta_set = deg2rad(90)
    fpc.attractor[1] = phi_set
    fpc.attractor[2] = beta_set
    fpc.phi = deg2rad(45)
    fpc.beta = deg2rad(0)
    fpc.psi_dot_set = nothing
    KiteControllers.navigate(fpc)
    @test rad2deg(fpc.chi_set) ≈ 30.68205617643342
end
nothing
