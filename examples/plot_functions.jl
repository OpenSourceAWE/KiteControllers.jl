# Core plot functions shared by plots.jl (interactive GUI) and batch_plot.jl (CLI).
# They are implemented in the package KitePlots (lib/KitePlots), so that the system
# image can store their compiled code.
using KitePlots: l_tether, force, v_reelout, _cycle_index, _plot_main, _plot_power,
                 _plot_control, _plot_control_II, _plot_winch_control, _plot_aerodynamics,
                 _plot_elev_az, _plot_elev_az_n, _plot_side_view, _plot_side_view_n,
                 _plot_front_view_n
