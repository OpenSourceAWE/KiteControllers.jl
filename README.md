# KiteControllers
[![Docs dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://opensourceawe.github.io/KiteControllers.jl/dev)
[![Build Status](https://github.com/OpenSourceAWE/KiteControllers.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/OpenSourceAWE/KiteControllers.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/OpenSourceAWE/KiteControllers.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/OpenSourceAWE/KiteControllers.jl)
[![DOI](https://img.shields.io/badge/DOI-10.5281%2Fzenodo.13255245-blue)](https://zenodo.org/doi/10.5281/zenodo.13255245)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Discrete controllers for kite power systems.

This package is part of Julia Kite Power Tools, which consists of the following packages:
<p align="center"><img src="docs/kite_power_tools.png" width="500" /></p>

## Installation
<details>
  <summary>Installation of Julia</summary>

If you do not have Julia installed yet, please read [Installing Julia 1.13 and VSCode](https://ufechner7.github.io/2026/10/24/installing-julia-1.13-and-vscode.html).

</details>

<details>
  <summary>Installation as package</summary>

### Installation of KiteControllers as package

It is suggested to use a local Julia environment. You can create it with:
```bash
mkdir myproject
cd myproject
julia --project=.
```
(don't forget typing the dot at the end), and then, on the Julia prompt enter:
```julia
using Pkg
pkg"add KiteControllers"
```
You can run the tests with:
```julia
using Pkg
pkg"test KiteControllers"
```
To add the examples and install the packages needed by the examples, run:
```julia
using KiteControllers
KiteControllers.install_examples()
exit()
```
</details>

<details>
  <summary>Installation using git</summary>

### Installation of KiteControllers using git

In most cases -- if you want to modify, tune and understand kite controllers -- it is better to check out this project from git. You can do this with:

```bash
git clone https://github.com/OpenSourceAWE/KiteControllers.jl.git
cd KiteControllers.jl
```

Then, run the install script (`-i` asks which Julia version to use and whether to add the alias `jl`, install Revise and precompile the tests; without `-i` it asks nothing) and optionally create a system image:

```bash
cd bin
./install -i
./create_sys_image
cd ..
```

The startup time without system image is about 30s, with system image 5s, but creating a system image takes 30 minutes or more. Building it needs at least 16 GB of RAM (8 GB on macOS) and at least 30 GB of RAM + swap.

On Linux you can install the `autopilot` GUI app as normal application with the command `bin/install_app`.

</details>

### Running the first example

You can now start Julia with `./bin/run_julia` and execute the autopilot or any other of the examples with:

```julia
include("examples/autopilot.jl")
```

Clicking on the "RUN" button starts the simulation. When the simulation is finished, you can click on the "OK"
button at the top left. After some time a plot of the flight should appear. You can use the drop-down menu
on the left to select other plots or the statistics. You can also load or save log files or projects.
A project consists of a kite/ physical system, controller settings and a wind condition.
<p align="center"><img src="./docs/src/autopilot.png" alt="Autopilot GUI" width="500" /></p>

You get a menu with all the examples by typing:

```julia
menu()
```

## Main Components

### Flight Path Calculator (FPCA)
The FPCA is a stateless component that calculates the coordinates of the attractor points and turn points that
determine the flight path. In addition, it calculates the desired turn radius of the turns.

### Flight Path Planner (FPP)
The Flight Path Planner executes the planned flight path using a state machine.

### SystemStateControl (SSC)
While the Flight Path Planner is in charge of calculating the flight path during automated power production, this
component handles other system states, like fully manual operation, automated winch control combined with manual 
steering, parking etc.

## Hints for developers/ contributors
If you want to modify this package, create a fork on github and checkout the fork using Git.
Then create a system image of all the packages, used by KiteControllers itself and the examples by running the script `bin/create_sys_image`. If you are on Windows make sure you have git-bash installed because this is a bash script. You can then launch Julia with the command `bin/run_julia` which is fast. Try to run the test scripts from the folder test to understand what they are doing.
Now you can modify the source code according to your needs, restart Julia, run the relevant test script again and see the effect.
If you are happy, commit your changes and create a pull request. If you have any questions, please ask them at https://discourse.julialang.org/ .

## License
This project is licensed under the MIT License. Please see the below WAIVER in association with the license.

## WAIVER
Technische Universiteit Delft hereby disclaims all copyright interest in the package “KiteControllers.jl” (controllers for airborne wind energy systems) written by the Author(s).

Prof.dr. H.G.C. (Henri) Werij, Dean of Aerospace Engineering

## Donations
If you like this software, please consider donating to https://gofund.me/bba01d43 .

## Scientific background
- [A Methodology for the Design of Kite-Power Control Systems](https://research.tudelft.nl/en/publications/a-methodology-for-the-design-of-kite-power-control-systems)
- [Flight path control of kite power systems in a turbulent wind environment](https://ieeexplore.ieee.org/document/7525563)

## Related
- [Research Fechner](https://research.tudelft.nl/en/publications/?search=wind+Fechner&pageSize=50&ordering=rating&descending=true) for the scientific background of this code
- The meta package [KiteSimulators](https://github.com/aenarete/KiteSimulators.jl) which contains all packages from Julia Kite Power Tools.
- the packages [KiteModels](https://github.com/OpenSourceAWE/KiteModels.jl) and [WinchModels](https://github.com/aenarete/WinchModels.jl) and [AtmosphericModels](https://github.com/OpenSourceAWE/AtmosphericModels.jl)
- the packages [KiteViewers](https://github.com/OpenSourceAWE/KiteViewers.jl) and [KiteUtils](https://github.com/OpenSourceAWE/KiteUtils.jl)
