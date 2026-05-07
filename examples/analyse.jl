using KiteControllers

OUTPUT_DIR::String = "output"

# Plot heading_rate and body_rate from the last recorded log file
let
    log_path = joinpath(OUTPUT_DIR, "last_sim_log")
    if isfile(log_path * ".arrow")
        log = load_log(basename(log_path); path=dirname(log_path))
        sl = log.syslog
        heading_rate_deg = rad2deg.(sl.heading_rate)
        body_rate_deg = rad2deg.([tr[3] for tr in sl.turn_rates])
        p = ControlPlots.plot(sl.time, [heading_rate_deg, body_rate_deg];
                              xlabel="time [s]", ylabel="rate [°/s]",
                              labels=["heading_rate", "body_rate"],
                              fig="rates")
        display(p)
        println("Plotted heading_rate and body_rate from: $log_path")
    else
        println("No log file found at: $(log_path).arrow")
    end
end