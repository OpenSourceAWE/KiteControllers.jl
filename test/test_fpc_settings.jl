@testset "FPCSettings defaults" begin
    fcs = FPCSettings(dt=0.05)
    # scalar/numeric fields
    @test fcs.dt           ≈ 0.05
    @test fcs.log_level    == 2
    @test fcs.p            ≈ 20.0
    @test fcs.i            ≈ 1.2
    @test fcs.d            ≈ 10.0
    @test fcs.gain         ≈ 0.04
    @test fcs.c1           ≈ 0.0612998898221
    @test fcs.c2           ≈ 1.22597628388
    @test fcs.k_c1         ≈ 1.6
    @test fcs.k_c2         ≈ 6.0
    @test fcs.k_c2_high    ≈ 12.0
    @test fcs.k_c2_int     ≈ 0.6
    @test fcs.k_ds         ≈ 2.0
    # boolean fields
    @test fcs.prn              == false
    @test fcs.prn_ndi_gain     == false
    @test fcs.prn_est_psi_dot  == false
    @test fcs.prn_va           == false
    @test fcs.use_radius       == true
    @test fcs.use_chi          == true
    @test fcs.reset_int1       == true
    @test fcs.reset_int2       == false
    @test fcs.reset_int1_to_zero == true
    @test fcs.init_opt_to_zero == false
end

@testset "FPCSettings dt override" begin
    # dt supplied to the constructor must always win, even over whatever the YAML says
    fcs = FPCSettings(dt=0.02)
    @test fcs.dt ≈ 0.02

    fcs2 = FPCSettings(dt=0.1)
    @test fcs2.dt ≈ 0.1
end

@testset "FPCSettings mutable" begin
    fcs = FPCSettings(dt=0.05)
    fcs.p    = 30.0
    fcs.gain = 0.05
    @test fcs.p    ≈ 30.0
    @test fcs.gain ≈ 0.05
end

@testset "FPCSettings load from YAML" begin
    fcs = FPCSettings(true; dt=0.05)
    # dt must be the value passed to the constructor, not the one in the YAML (0.025)
    @test fcs.dt ≈ 0.05
    # values that match the YAML file (data/fpc_settings.yaml)
    @test fcs.log_level == 2
    @test fcs.p         ≈ 20.0
    @test fcs.i         ≈ 1.2
    @test fcs.d         ≈ 10.0
    @test fcs.gain      ≈ 0.04
    @test fcs.c1        ≈ 0.0612998898221
    @test fcs.c2        ≈ 1.22597628388
    @test fcs.k_c1      ≈ 1.6
    @test fcs.k_c2      ≈ 6.0
    @test fcs.k_c2_high ≈ 12.0
    @test fcs.k_c2_int  ≈ 0.6
    @test fcs.k_ds      ≈ 2.0
    @test fcs.use_radius       == true
    @test fcs.use_chi          == true
    @test fcs.reset_int1       == true
    @test fcs.reset_int2       == false
    @test fcs.reset_int1_to_zero == true
    @test fcs.init_opt_to_zero == false
end
