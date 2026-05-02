# provides a terminal text dialog to set default_turbulence in data/gui.yaml

if ! @isdefined yaml_utils_loaded
    include("yaml_utils.jl")
    const yaml_utils_loaded = true
end

function set_default_turbulence()
    data_dir = joinpath(@__DIR__, "..", "data")
    gui_yaml = joinpath(data_dir, "gui.yaml")
    gui_yaml_default = gui_yaml * ".default"

    if !isfile(gui_yaml)
        if isfile(gui_yaml_default)
            cp(gui_yaml_default, gui_yaml)
        else
            println("Missing $gui_yaml and fallback $gui_yaml_default")
            return
        end
    end

    lines = readfile(gui_yaml)

    current = nothing
    for line in lines
        m = match(r"^\s*default_turbulence:\s*([-+0-9.eE]+)", line)
        if !isnothing(m)
            try
                current = parse(Float64, m.captures[1])
            catch
                current = nothing
            end
            break
        end
    end

    if isnothing(current)
        println("Could not read current default_turbulence in $gui_yaml")
        return
    end

    println("Current default_turbulence: $current")
    print("Enter new default_turbulence [0.0..1.0] (blank to cancel): ")
    input = strip(readline())

    if isempty(input)
        println("Cancelled.")
        return
    end

    value = try
        parse(Float64, input)
    catch
        println("Invalid number: $input")
        return
    end

    if value < 0.0 || value > 1.0
        println("Value out of range. Please use a value between 0.0 and 1.0")
        return
    end

    new_lines = change_value(lines, "default_turbulence:", value)
    writefile(new_lines, gui_yaml)
    println("default_turbulence set to: $value")
end
