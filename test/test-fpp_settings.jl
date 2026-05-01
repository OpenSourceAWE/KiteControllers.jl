# activate the test environment if needed
using Pkg
if ! ("Test" ∈ keys(Pkg.project().dependencies))
    Pkg.activate(@__DIR__)
end
using Test, KiteControllers
_old_data_path = KiteUtils.get_data_path()
try
    KiteUtils.set_data_path("")

    @testset "FPPSettings defaults" begin
        fpps = FPPSettings()
        @test fpps.log_level          == 2
        @test fpps.min_depower        ≈ 22.0
        @test fpps.max_depower        ≈ 40.0
        @test fpps.parking_depower    ≈ 25.0
        @test fpps.min_length         ≈ 168.5
        @test fpps.max_length         ≈ 500.0
        @test fpps.max_height         ≈ 500.0
        @test fpps.beta_set           ≈ 26.0
        @test fpps.w_fig              ≈ 36.0
        @test fpps.psi_dot_max        ≈ 3.0
        @test fpps.r_min              ≈ 3.0
        @test fpps.r_max              ≈ 4.5
        @test fpps.heading_offset_low  ≈ 22.0
        @test fpps.heading_offset_int  ≈ 32.0
        @test fpps.heading_offset_high ≈ 54.0
        @test fpps.heading_offset_up   ≈ 60.0
        @test fpps.heading_upper_turn  ≈ 335.0
        @test fpps.k_factor           ≈ 1.0
        @test fpps.timeout            ≈ 145.0
        @test length(fpps.corr_vec)   == 12
        @test fpps.corr_vec[1]        ≈ 24.02
        @test fpps.corr_vec[end]      ≈ 3.84
    end

    @testset "FPPSettings mutable" begin
        fpps = FPPSettings()
        fpps.beta_set  = 30.0
        fpps.k_factor  = 1.5
        @test fpps.beta_set ≈ 30.0
        @test fpps.k_factor ≈ 1.5
    end

    @testset "FPPSettings load from YAML" begin
        fpps = FPPSettings(true)
        # The fpp_settings.yaml is not found in the KiteUtils test data path,
        # so FPPSettings(true) gracefully falls back to defaults.
        @test fpps.log_level         == 2
        @test fpps.beta_set          ≈ 26.0
        @test fpps.k_factor          ≈ 1.0
        @test fpps.heading_upper_turn ≈ 335.0
        @test fpps.min_depower       ≈ 22.0
        @test fpps.max_depower       ≈ 40.0
        @test fpps.parking_depower   ≈ 25.0
        @test fpps.min_length        ≈ 168.5
        @test fpps.max_length        ≈ 500.0
        @test fpps.w_fig             ≈ 36.0
        @test fpps.psi_dot_max       ≈ 3.0
        @test fpps.r_min             ≈ 3.0
        @test fpps.r_max             ≈ 4.5
        @test fpps.heading_offset_low  ≈ 22.0
        @test fpps.heading_offset_int  ≈ 32.0
        @test fpps.heading_offset_high ≈ 54.0
        @test fpps.heading_offset_up   ≈ 60.0
        @test fpps.corr_vec[1]       ≈ 24.02
        @test fpps.corr_vec[end]     ≈ 3.84
    end

    @testset "FPPSettings corr_vec padding" begin
        # Verify that a short corr_vec loaded from YAML is padded with trailing
        # zeros up to the default length, and that the original values are preserved.
        mktempdir() do tmpdir
            open(joinpath(tmpdir, "system.yaml"), "w") do f
                println(f, "system:")
                println(f, "    fpp_settings: \"fpp_settings.yaml\"")
            end
            open(joinpath(tmpdir, "fpp_settings.yaml"), "w") do f
                println(f, "fpp_settings:")
                println(f, "    corr_vec: [1.0, 2.0, 3.0]")
            end
            old_project = KiteUtils.PROJECT
            try
                KiteUtils.set_data_path(tmpdir)
                KiteUtils.PROJECT = "system.yaml"
                fpps = FPPSettings(true)
                default_len = length(FPPSettings().corr_vec)
                @test length(fpps.corr_vec) == default_len
                @test fpps.corr_vec[1] ≈ 1.0
                @test fpps.corr_vec[2] ≈ 2.0
                @test fpps.corr_vec[3] ≈ 3.0
                for i in 4:default_len
                    @test fpps.corr_vec[i] ≈ 0.0
                end
            finally
                KiteUtils.PROJECT = old_project
            end
        end
    end
finally
    KiteUtils.set_data_path(_old_data_path)
end
nothing
