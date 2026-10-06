### Changed
- BREAKING: `bin/install` runs the test suite only with `--tests`; `--no-tests` and the question about tests are gone.
- `bin/install` no longer runs `juliaup default`, adds Revise to the global environment or appends the `jl` alias to `~/.bashrc`/`~/.zshrc`. When the active Julia has no `Manifest-v<major>.toml.default`, it uses the newest installed Julia that has one through `JULIAUP_CHANNEL`, so `-y` no longer fails on an unsupported default Julia.
- `bin/install --update` runs `Pkg.update` on the existing manifest instead of deleting it first.
- `bin/run_julia` picks the Julia the same way, and loads Revise only when it is installed.
