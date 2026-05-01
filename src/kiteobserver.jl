# observe the flight path and collect useful information to optimize it
"""
    KiteObserver

Collects flight path statistics from a simulation log to enable correction of the
elevation profile over successive figure-of-eight cycles.

Construct with `KiteObserver()`, then call `observe!(ob, log)` to populate.
"""
mutable struct KiteObserver
    time::Vector{Float64}
    length::Vector{Float64}
    fig8::Vector{Int64}
    elevation::Vector{Float64}
    corr_vec::Vector{Float64}
end
function KiteObserver()
    KiteObserver(Float64[], Float64[], Int64[], Float64[], Float64[])
end

"""
    observe!(ob::KiteObserver, log::SysLog, elev_nom=26)

Process a `SysLog` and populate the `KiteObserver` with per-half-cycle
elevation measurements and correction values for the flight path planner.
"""
function observe!(ob::KiteObserver, log::SysLog, elev_nom=26)
    sl  = log.syslog

    # Collect indices of valid entries (cycle 2, sys_state in (6, 8))
    valid_indices = Int[]
    for i in 1:length(sl.azimuth)
        if sl.cycle[i] == 2 && sl.sys_state[i] in (6, 8)
            push!(valid_indices, i)
        end
    end

    if isempty(valid_indices)
        return nothing
    end

    # Find positions within valid_indices where the sign of azimuth changes
    crossing_positions = Int[]
    last_sign = -1
    for j in 1:length(valid_indices)
        s = sign(sl.azimuth[valid_indices[j]])
        if s != last_sign
            push!(crossing_positions, j)
            last_sign = s
        end
    end

    if isempty(crossing_positions)
        return nothing
    end

    # Pre-compute elevation in degrees for all valid entries
    n_valid = length(valid_indices)
    elevs = [rad2deg(sl.elevation[valid_indices[j]]) for j in 1:n_valid]

    # For each crossing record metadata and the average of:
    #   last_max  – max elevation from the previous crossing to this crossing
    #   next_min  – min elevation from this crossing to the next crossing
    for k in 1:length(crossing_positions)
        cp       = crossing_positions[k]
        prev_cp  = k > 1                          ? crossing_positions[k-1] : 1
        next_cp  = k < length(crossing_positions) ? crossing_positions[k+1] : n_valid

        last_max = @views maximum(elevs[prev_cp:cp])
        next_min = @views minimum(elevs[cp:next_cp])

        i = valid_indices[cp]
        push!(ob.time,      Float64(sl.time[i]))
        push!(ob.length,    Float64(sl.l_tether[i][1]))
        push!(ob.fig8,      Int64(sl.fig_8[i]))
        push!(ob.elevation, (last_max + next_min) / 2.0)
    end

    if length(ob.fig8) == 0
        return nothing
    end
    for fig8 in 0:maximum(ob.fig8)
        for i in 1:length(ob.fig8)
            if ob.fig8[i]==fig8
                if isodd(i)
                    cor_right=(elev_nom-ob.elevation[i])
                    push!(ob.corr_vec, cor_right)
                else
                    cor_left=(elev_nom-ob.elevation[i])
                    push!(ob.corr_vec, cor_left)
                end
            end
        end
    end
    nothing
end

function corrected_elev(corr_vec::Vector{Float64}, fig8, elev_nom)
    fig8 = Int64(round(fig8))
    if ! isnothing(corr_vec) && fig8 >= 0 && length(corr_vec) > 0
        if 2fig8 + 1 <= length(corr_vec)-1 
            elev_right = elev_nom + corr_vec[2fig8+2]
        else
            elev_right = elev_nom + corr_vec[end]
        end
        if 2fig8+2 <= length(corr_vec)-1
            elev_left = elev_nom + corr_vec[2fig8+3]
        else
            elev_left = elev_right
        end
    else
        elev_right=elev_nom
        elev_left=elev_nom
    end
    elev_right, elev_left
end

# calculate the corrected elevations per figure-of-eight, one for the left and one for the right attractor point
function corrected_elev(ob::KiteObserver, fig8, elev_nom)
    corrected_elev(ob.corr_vec, fig8, elev_nom)
end

# correction for first (lowest) turn
function corrected_elev(corr_vec, elev_nom)
    if isnothing(corr_vec) || length(corr_vec) == 0
        return elev_nom
    end
    elev_nom + corr_vec[1]
end