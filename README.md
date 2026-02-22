# ruby-bindgen

Generate Ruby bindings from C and C++ headers.

## Install

```console
git clone https://github.com/ruby-rice/ruby-bindgen.git
cd ruby-bindgen
rake install
```

## Run

```bash
mkdir -p /path/to/output
ruby-bindgen /path/to/config.yaml
```

`output` must already exist and be a directory.

## Docs

- [Documentation Index](docs/index.md)
- [Configuration](docs/configuration.md)
- [C++ Bindings (Rice)](docs/cpp_bindings.md)
- [C Bindings (FFI)](docs/c_bindings.md)
- [CMake Bindings](docs/cmake_bindings.md)
- [Prior Art](docs/prior_art.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Contributing](docs/contributing.md)
