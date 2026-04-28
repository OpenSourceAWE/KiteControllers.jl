using KiteControllers, KiteModels
using Test

cd("..")
KiteUtils.set_data_path("") 

include("test_flightpathcontroller.jl")
include("test_model_and_control.jl")
include("test_copy_functions.jl")
include("test_fpc_settings.jl")
include("aqua.jl")
