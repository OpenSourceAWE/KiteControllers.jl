# Shared helper accessors used by the plot functions and examples/autopilot.jl

function l_tether(sl)
    getindex.(sl.l_tether, 1)
end

function force(sl)
    getindex.(sl.winch_force, 1)
end

function v_reelout(sl)
    getindex.(sl.v_reelout, 1)
end