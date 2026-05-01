# provides a terminal menu to select a project (*.yml file) from the data directory
# and stores the result in gui.yaml

using REPL.TerminalMenus

if ! @isdefined yaml_utils_loaded
    include("yaml_utils.jl")
    const yaml_utils_loaded = true
end

function select_project()
    data_dir = joinpath(@__DIR__, "..", "data")
    gui_yaml = joinpath(data_dir, "gui.yaml")
    gui_yaml_default = gui_yaml * ".default"

    # Collect all *.yml project files from the data directory
    projects = sort(filter(f -> endswith(f, ".yml"), readdir(data_dir)))

    if isempty(projects)
        println("No *.yml project files found in $data_dir")
        return
    end

    if !isfile(gui_yaml)
        if isfile(gui_yaml_default)
            cp(gui_yaml_default, gui_yaml)
        else
            println("Missing $gui_yaml and fallback $gui_yaml_default")
            return
        end
    end

    # Read current project from gui.yaml
    gui_lines = readfile(gui_yaml)
    current = ""
    for line in gui_lines
        m = match(r"^\s*project:\s*(\S+)", line)
        if !isnothing(m)
            current = m.captures[1]
            break
        end
    end
    prompt = isempty(current) ? "\nSelect a project: " : "\nSelect a project (current: $current): "

    options = [projects; "quit"]
    menu = RadioMenu(options, pagesize=8)
    choice = request(prompt, menu)

    if choice != -1 && choice != length(options)
        selected = options[choice]
        lines = change_value(gui_lines, "project:", selected)
        writefile(lines, gui_yaml)
        println("Project set to: $selected")
    else
        println("Selection cancelled.")
    end
end
