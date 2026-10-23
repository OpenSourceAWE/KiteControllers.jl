# Plot functions for the log files of the examples. They live in a package and not in the
# examples, because a system image can only store compiled code of functions defined in
# packages; defined in Main, the first plot of a log took about 20 s to compile.
module KitePlots

using KiteUtils, LaTeXStrings, MakieControlPlots

# public, but not exported: the examples define plot functions without arguments with
# the same names, which load the log file and call these
public plot_main, plot_power, plot_control, plot_control_II, plot_winch_control,
       plot_aerodynamics, plot_elev_az, plot_side_view, plot_front_view,
       l_tether, force, v_reelout

include("plot_helpers.jl")
include("plot_functions.jl")

end
