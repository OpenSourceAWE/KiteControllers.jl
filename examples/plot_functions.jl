# Core plot functions shared by plots.jl (interactive GUI) and batch_plot.jl (CLI).
# They are implemented in the package KitePlots (lib/KitePlots), so that the system
# image can store their compiled code. They take the log as argument, the functions
# with the same names in plots.jl and batch_plot.jl load it first.
import KitePlots
using KitePlots: l_tether, force, v_reelout
