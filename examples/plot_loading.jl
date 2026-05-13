using Pkg
if ! ("ControlPlots" ∈ keys(Pkg.project().dependencies))
    Pkg.activate(@__DIR__)
end

using KiteControllers
using KiteUtils: load_log
using ControlPlots

OUTPUT_DIR::String = "output"

# Plot force vs time from the last recorded log file
let
    log_path = joinpath(OUTPUT_DIR, "last_sim_log")
    if isfile(log_path * ".arrow")
        log = load_log(basename(log_path); path=dirname(log_path))
        sl = log.syslog
        force = hcat(sl.winch_force...)[1,:]
        p = ControlPlots.plot(sl.time, force;
                  xlabel="time [s]",
                  ylabel="force [N]",
                  fig="loading")
        display(p)
        println("Plotted force vs time from: $log_path")
    else
        println("No log file found at: $(log_path).arrow")
    end
end