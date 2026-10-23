# Plot functions for the log files of the examples. They live in a package and not in the
# examples, because a system image can only store compiled code of functions defined in
# packages; defined in Main, the first plot of a log took about 20 s to compile.
module KitePlots

using KiteUtils, LaTeXStrings, MakieControlPlots

include("plot_helpers.jl")
include("plot_functions.jl")

end
