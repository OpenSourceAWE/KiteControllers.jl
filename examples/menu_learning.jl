# provides a terminal menu with the options:
# - "select_project": calls select_project() to select a project from the data directory
# - "clear_corrections": clears all corrections from the current project
# - "train()": runs the training loop from learn_corrections.jl
# - "quit": exits the menu

using REPL.TerminalMenus

include("select_project.jl")
include("learn_corrections.jl")

options = ["select_project()",
           "include(\"clear_corrections.jl\")",
           "train()",
           "plot()",
           "residual(full_sim=true)",
           "plot(full_sim=true)",
           "include(\"autopilot.jl\")",
           "quit"]

function learning_menu()
    active = true
    while active
        menu = RadioMenu(options, pagesize=9)
        choice = request("\nProject: $(read_project())  — Choose function to execute or `q` to quit: ", menu)

        if choice != -1 && choice != length(options)
            eval(Meta.parse(options[choice]))
        else
            println("Left menu. Press <ctrl><d> to quit Julia!")
            active = false
        end
    end
end

learning_menu()