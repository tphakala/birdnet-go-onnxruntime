# birdnet-go-onnxruntime

Pre-compiled ONNX Runtime shared libraries with hardware Execution Provider (EP)
support for [BirdNET-Go](https://github.com/tphakala/birdnet-go).

## Available Builds

| Platform | Architecture | Execution Providers | Format |
|----------|-------------|---------------------|--------|
| Linux | x86_64 | OpenVINO, CPU | tar.gz |
| Windows | x86_64 | OpenVINO, DirectML, CPU | zip |

## Download

Download archives from [GitHub Releases](https://github.com/tphakala/birdnet-go-onnxruntime/releases).

Each archive contains:
- ONNX Runtime shared libraries with EP support compiled in
- `metadata.json` with version info, checksums, and runtime dependency notes

## Versioning

Tags follow `v{ORT_VERSION}-{BUILD_NUMBER}`:
- `v1.25.1-1` - first build of ORT 1.25.1
- `v1.25.1-2` - re-release of same ORT version
- `v1.26.0-1` - new ORT version

## Creating a Release

```bash
make release ORT_VERSION=1.25.1 BUILD=1
```

This creates and pushes tag `v1.25.1-1`. GitHub Actions builds all platforms
and creates the release automatically.

## Runtime Dependencies

These builds include only the ONNX Runtime libraries. EP-specific runtime
dependencies must be installed separately:

### OpenVINO (Linux)
- Install OpenVINO runtime from Intel APT repo
- Install `intel-opencl-icd` for GPU compute
- Add user to `render` and `video` groups for `/dev/dri` access

### OpenVINO (Windows)
- Install OpenVINO runtime from intel.com

### DirectML (Windows)
- Requires DirectX 12 compatible GPU
- DirectML runtime is included in Windows 10 1903+

## License

MIT License (same as ONNX Runtime)
