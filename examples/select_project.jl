# provides a terminal menu to select a project (*.yml file) from the data directory
# and stores the result in gui.yaml

using REPL.TerminalMenus

include("yaml_utils.jl")

data_dir = joinpath(@__DIR__, "..", "data")
gui_yaml = joinpath(data_dir, "gui.yaml")

# Collect all *.yml project files from the data directory
projects = sort(filter(f -> endswith(f, ".yml"), readdir(data_dir)))

if isempty(projects)
    println("No *.yml project files found in $data_dir")
else
    menu = RadioMenu(projects, pagesize=8)
    choice = request("\nSelect a project: ", menu)

    if choice != -1
        selected = projects[choice]
        lines = readfile(gui_yaml)
        lines = change_value(lines, "project:", selected)
        writefile(lines, gui_yaml)
        println("Project set to: $selected")
    else
        println("Selection cancelled.")
    end
end
