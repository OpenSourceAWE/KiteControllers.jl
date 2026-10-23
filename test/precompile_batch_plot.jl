__PRECOMPILE__ = true
let
    include("../examples/batch_plot.jl")

    for (name, fn) in MENU_ITEMS
        name == "select project" && continue
        println("Precompiling $name ...")
        try
            fn()
            sleep(1)
            GC.gc()
        catch e
            println("  Skipped $name: $e")
        end
    end

    # plots.jl (the autopilot) calls plot_power without energy; each combination of
    # keyword arguments is a specialization of its own, which the call above does not cover
    println("Precompiling plot_power of the autopilot ...")
    try
        KitePlots.plot_power(load_plot_log(); dt=0.05)
        sleep(1)
        GC.gc()
    catch e
        println("  Skipped plot_power of the autopilot: $e")
    end

end

GC.gc(true)
let mem = Sys.free_memory() / 1024^2
    @info "Free memory: $(round(mem; digits=1)) MB"
end

@info "Precompile script precompile_batch_plot.jl has completed execution."
