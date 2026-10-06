### Added
- Julia 1.13 support, with a `Manifest-v1.13.toml.default` and Julia 1.13 in CI.

### Changed
- `bin/update_default_manifest` takes the Julia versions to update as arguments, defaulting to every version with a `Manifest-v<major>.toml.default`, instead of asking for one and switching the `juliaup` default.
