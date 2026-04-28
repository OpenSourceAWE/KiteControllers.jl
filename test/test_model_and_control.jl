# activate the test environment if needed
using Pkg
if ! ("Test" ∈ keys(Pkg.project().dependencies))
    Pkg.activate(@__DIR__)
end
using Test, KiteControllers, KiteModels

@testset "KiteModel" begin
    fcs = FPCSettings(dt=0.05)
    fcs.dt = 0.02
    km = KiteControllers.KiteModel(fcs)
    @test km.omega == 0.08
    x = [0.0, 0]
    x0, x1, psi_dot = KiteControllers.calc_x0_x1_psi_dot(km, x)
    @test x0 ≈ 1.5707963267948966
    @test x1 ≈ 0.5759586531581288
    @test psi_dot ≈ 0.0
    x = [0.1, 0]
    x0, x1, psi_dot = KiteControllers.calc_x0_x1_psi_dot(km, x)
    @test x0 ≈ 1.571422282317272
    @test x1 ≈ 0.5759576516293584
    @test psi_dot ≈ 0.031297776118780624
    x = [0.1, 0.1]
    x0, x1, psi_dot = KiteControllers.calc_x0_x1_psi_dot(km, x)
    @test x0 ≈ 1.571419155146939
    @test x1 ≈ 0.5759576566328299
    @test psi_dot ≈ 0.031141417602125847
    KiteControllers.solve(km)
    @test km.psi_dot ≈ 0.262921024533129
    KiteControllers.on_timer(km)
end

@testset "SystemStateControl" begin
    wcs = WCSettings(dt=0.05)
    fcs = FPCSettings(dt=0.05)
    fpps = FPPSettings()
    ssc = SystemStateControl(wcs, fcs, fpps; u_d0=0.01 * se().depower_offset, u_d=0.01 * se().depower, v_wind = se().v_wind)
    on_parking(ssc)
    @test ssc.state == ssParking
    on_autopilot(ssc)
    @test ssc.state == ssPowerProduction
    on_reelin(ssc)
    @test ssc.state == ssReelIn
    on_stop(ssc)
    @test ssc.state == ssManualOperation
    v_set = calc_v_set(ssc)
    @test isnothing(v_set)
    kcu = KCU(se())
    kps4 = KPS4(kcu)
    integrator = KiteModels.init!(kps4, stiffness_factor=0.1)
    sys_state = SysState(kps4)
    on_new_systate(ssc, sys_state)
    v_set = calc_v_set(ssc)
    @test v_set >= 0.0 && v_set < 0.1
    u_s = calc_steering(ssc)
    println(u_s)
end

@testset "FlightPathCalculator" begin
    fcs = FPCSettings(dt=0.05)
    fpps = FPPSettings()
    fpc = FlightPathController(fcs; u_d0=0.01 * se().depower_offset, u_d=0.01 * se().depower)
    fpca = FlightPathCalculator(fpc, fpps)
    vec=[1.0,2]
    res = KiteControllers.addy(vec, 0.5)
    @test res == [1.0, 2.5]
    res = KiteControllers.addxy(vec, 1.5, 1.0)
    @test res == [2.5, 3.0]
    KiteControllers.set_v_wind_gnd(fpca, 8.2)
    KiteControllers.set_v_wind_gnd(fpca, 8.06)
    KiteControllers.set_v_wind_gnd(fpca, 8.3)
    KiteControllers.set_v_wind_gnd(fpca, 7.2)
    KiteControllers.set_v_wind_gnd(fpca, 6.2)
    KiteControllers.set_v_wind_gnd(fpca, 5.2)
    KiteControllers.set_v_wind_gnd(fpca, 3.7)
    KiteControllers.set_v_wind_gnd(fpca, 3.6)
    KiteControllers.set_v_wind_gnd(fpca, 8.3)
    # @test fpca._elevation_offset_p2 ==  11.0
    phi = deg2rad(0)
    beta = deg2rad(30)
    KiteControllers.set_azimuth_elevation(fpca, phi, beta)
    beta_set = 30.0
    KiteControllers._calc_beta_c1(fpca, beta_set)
    # KiteControllers._calc_k2_k3(fpca, beta_set)
    KiteControllers._calc_t1(fpca, beta_set)
    KiteControllers.calc_p1(fpca, beta_set)
    KiteControllers.calc_p2(fpca, beta_set)
    KiteControllers.calc_p3(fpca)
    KiteControllers.calc_p4(fpca)
    KiteControllers.calc_t5(fpca, beta_set)
    KiteControllers.publish(fpca)
end

@testset "FlightPathPlanner" begin
    fcs = FPCSettings(dt=0.05)
    fpps = FPPSettings()
    fpc = FlightPathController(fcs; u_d0=0.01 * se().depower_offset, u_d=0.01 * se().depower)
    fpca = FlightPathCalculator(fpc, fpps)
    fpp = FlightPathPlanner(fpps, fpca)
    @test fpp.u_d_ro == 0.22
    @test ! KiteControllers.is_active(fpp)
    @test KiteControllers.get_state(fpp) == 0
    phi = 0.0
    beta = 0.0
    heading = 0.0
    course = 0.0
    v_a = 10.0
    u_d = 0.25
    on_new_systate(fpp, phi, beta, heading, course, v_a, u_d)
    depower = u_d
    length = 150.0
    height = 100.0
    time = 0.0
    KiteControllers.on_new_data(fpp, depower, length, heading, height, time)
    fpp._state = POWER
    KiteControllers.on_new_data(fpp, depower, length, heading, height, time)
    fpp._state = LOW_LEFT
    KiteControllers.on_new_data(fpp, depower, length, heading, height, time)
    fpp._state = FLY_LEFT
    KiteControllers.on_new_data(fpp, depower, length, heading, height, time)
    fpp._state = TURN_LEFT
    KiteControllers.on_new_data(fpp, depower, length, heading, height, time)
    fpp._state = FLY_RIGHT
    KiteControllers.on_new_data(fpp, depower, length, heading, height, time)
    fpp._state = UP_TURN
    KiteControllers.on_new_data(fpp, depower, length, heading, height, time)
    fpp._state = UP_FLY_UP
    KiteControllers.on_new_data(fpp, depower, length, heading, height, time)
    fpp._state = DEPOWER
    KiteControllers.on_new_data(fpp, depower, length, heading, height, time)  
    fpp.count = 50
    KiteControllers.on_new_data(fpp, depower, length, heading, height, time)   
    KiteControllers.start(fpp, se().v_wind)
    KiteControllers._switch(fpp, POWER)
    @test fpp._state == POWER
    KiteControllers._switch(fpp, POWER)
    KiteControllers._switch(fpp, LOW_RIGHT)
    @test fpp._state == LOW_RIGHT
    KiteControllers._switch(fpp, LOW_TURN)
    @test fpp._state == LOW_TURN
    KiteControllers._switch(fpp, LOW_LEFT)
    @test fpp._state == LOW_LEFT
    KiteControllers._switch(fpp, FLY_RIGHT)
    @test fpp._state == FLY_RIGHT
    KiteControllers._switch(fpp, TURN_LEFT)
    @test fpp._state == TURN_LEFT
    KiteControllers._switch(fpp, TURN_RIGHT)
    @test fpp._state == TURN_RIGHT
    KiteControllers._switch(fpp, FLY_LEFT)
    @test fpp._state == FLY_LEFT
    KiteControllers._switch(fpp, UP_TURN)
    @test fpp._state == UP_TURN
    KiteControllers._switch(fpp, UP_TURN_LEFT)
    @test fpp._state == UP_TURN_LEFT
    KiteControllers._switch(fpp, UP_FLY_UP)
    @test fpp._state == UP_FLY_UP 
    KiteControllers._switch(fpp, PARKING)
    @test fpp._state == PARKING
end
nothing