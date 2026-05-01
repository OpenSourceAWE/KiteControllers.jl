# provides a terminal menu with the options:
# - "select_project": calls select_project() to select a project from the data directory
# - "clear_corrections": clears all corrections from the current project
# - "learn_corrections": calls learn_corrections.jl to learn corrections for the current project
# - "quit": exits the menu

using REPL.TerminalMenus

include("select_project.jl")

options = ["select_project()",
           "clear_corrections = include(\"clear_corrections.jl\")",
           "learn_corrections = include(\"learn_corrections.jl\")",
           "quit"]

function learning_menu()
    active = true
    while active
        menu = RadioMenu(options, pagesize=8)
        choice = request("\nChoose function to execute or `q` to quit: ", menu)

        if choice != -1 && choice != length(options)
            eval(Meta.parse(options[choice]))
        else
            println("Left menu. Press <ctrl><d> to quit Julia!")
            active = false
        end
    end
end

learning_menu()