# activate the test environment if needed
using Pkg
if ! ("Test" ∈ keys(Pkg.project().dependencies))
    Pkg.activate(@__DIR__)
end
using Test, KiteControllers, KiteUtils, StaticArrays

# Number of tether particles used for all test logs
const P_TEST = 4

# Build a minimal SysLog by filling a Logger with hand-crafted SysState entries.
# Each entry has:
#   var_01  = cycle (2 triggers observe!)
#   var_02  = fig8 index
#   sys_state = 6 (FLY_RIGHT) or 8 (FLY_LEFT)
#   azimuth   = alternating sign to trigger sign-change detection
#   elevation = known value [rad]
#   l_tether  = MVector of length P_TEST (first element = total tether length)
function build_test_log(entries; n_steps=length(entries))
    logger = Logger(P_TEST, n_steps)
    for (i, e) in enumerate(entries)
        ss = SysState{P_TEST}()
        ss.time      = Float64(i) * 0.05
        ss.sys_state = Int16(get(e, :sys_state, 0))
        ss.var_01    = Float32(get(e, :cycle,    0))
        ss.var_02    = Float32(get(e, :fig8,     0))
        ss.azimuth   = Float32(get(e, :azimuth,  0.0))
        ss.elevation = Float32(get(e, :elevation, 0.0))
        ss.l_tether .= MVector{4, Float32}(get(e, :l_tether, 150.0), 0, 0, 0)
        log!(logger, ss)
    end
    KiteUtils.sys_log(logger)
end

@testset "KiteObserver – empty log (no cycle-2 data)" begin
    # All entries have cycle=0 → observe! should find nothing
    entries = [Dict(:cycle => 0, :sys_state => 6, :azimuth => 0.1f0, :elevation => deg2rad(26.0)) for _ in 1:10]
    flight_log = build_test_log(entries)
    ob = KiteObserver()
    result = observe!(ob, flight_log, 26.0)
    @test isnothing(result)
    @test isempty(ob.corr_vec)
    @test isempty(ob.elevation)
end

@testset "KiteObserver – cycle-2 data with known elevations" begin
    # Simulate a sequence of cycle-2 entries where azimuth changes sign.
    # The observer records elevation at each sign change.
    # We arrange two sign changes (right-to-left, left-to-right) at known elevations.
    elev_nom = 26.0                       # nominal elevation [deg]
    elev_right_rad = deg2rad(24.0)        # measured elevation on right pass
    elev_left_rad  = deg2rad(28.0)        # measured elevation on left pass

    # Build entries:
    #  start with negative azimuth to match the initial last_sign=-1 (no spurious sign change)
    #  then alternate: positive (FLY_RIGHT), negative (FLY_LEFT)
    entries = [
        # negative azimuth block – no sign change from initial last_sign=-1
        Dict(:cycle => 2, :sys_state => 8, :azimuth => -0.3, :elevation => elev_left_rad,  :fig8 => 0),
        Dict(:cycle => 2, :sys_state => 8, :azimuth => -0.2, :elevation => elev_left_rad,  :fig8 => 0),
        # sign change to positive azimuth → record elevation (FLY_RIGHT, fig8=0)
        Dict(:cycle => 2, :sys_state => 6, :azimuth =>  0.1, :elevation => elev_right_rad, :fig8 => 0),
        Dict(:cycle => 2, :sys_state => 6, :azimuth =>  0.2, :elevation => elev_right_rad, :fig8 => 0),
        Dict(:cycle => 2, :sys_state => 6, :azimuth =>  0.3, :elevation => elev_right_rad, :fig8 => 0),
        # sign change to negative azimuth → record elevation (FLY_LEFT, fig8=0)
        Dict(:cycle => 2, :sys_state => 8, :azimuth => -0.1, :elevation => elev_left_rad,  :fig8 => 0),
        Dict(:cycle => 2, :sys_state => 8, :azimuth => -0.2, :elevation => elev_left_rad,  :fig8 => 0),
    ]
    flight_log = build_test_log(entries)
    ob = KiteObserver()
    observe!(ob, flight_log, elev_nom)

    # Two sign changes ⇒ 2 recorded elevation samples
    @test length(ob.elevation) == 2
    @test ob.elevation[1] ≈ rad2deg(elev_right_rad) atol=0.01
    @test ob.elevation[2] ≈ rad2deg(elev_left_rad)  atol=0.01

    # corr_vec entries = elev_nom − measured_elevation
    @test length(ob.corr_vec) == 2
    @test ob.corr_vec[1] ≈ elev_nom - rad2deg(elev_right_rad) atol=0.01
    @test ob.corr_vec[2] ≈ elev_nom - rad2deg(elev_left_rad)  atol=0.01
end

@testset "corrected_elev(corr_vec, fig8, elev_nom)" begin
    elev_nom  = 26.0
    corr_vec  = [2.0, -1.0, 3.0, 0.5]   # corrections for fig8=0 (right, left) and fig8=1 (right, left)

    # fig8=0: indices 2 and 3 (1-indexed: corr_vec[2], corr_vec[3])
    r0, l0 = KiteControllers.corrected_elev(corr_vec, 0, elev_nom)
    @test r0 ≈ elev_nom + corr_vec[2]
    @test l0 ≈ elev_nom + corr_vec[3]

    # fig8=1: indices 4 and 5; index 5 doesn't exist so left = right
    r1, l1 = KiteControllers.corrected_elev(corr_vec, 1, elev_nom)
    @test r1 ≈ elev_nom + corr_vec[4]
    @test l1 ≈ r1  # fallback: same as right

    # fig8 out of range → clamp to last element
    r_big, l_big = KiteControllers.corrected_elev(corr_vec, 10, elev_nom)
    @test r_big ≈ elev_nom + corr_vec[end]
    @test l_big ≈ r_big

    # empty corr_vec → return elev_nom
    r_empty, l_empty = KiteControllers.corrected_elev(Float64[], 0, elev_nom)
    @test r_empty == elev_nom
    @test l_empty == elev_nom
end

@testset "corrected_elev(corr_vec, elev_nom) – first turn variant" begin
    elev_nom = 26.0
    corr_vec = [5.0, 2.0, -1.0]

    # Uses corr_vec[1]
    @test KiteControllers.corrected_elev(corr_vec, elev_nom) ≈ elev_nom + corr_vec[1]

    # Empty or nothing → elev_nom unchanged
    @test KiteControllers.corrected_elev(Float64[], elev_nom) == elev_nom
    @test KiteControllers.corrected_elev(nothing,   elev_nom) == elev_nom
end
