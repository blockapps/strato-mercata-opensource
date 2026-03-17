# STRATO Platform - GitHub Actions Build

This fork includes GitHub Actions workflows to build the STRATO platform on x86_64 runners, solving Apple Silicon compatibility issues.

## Workflows

### 1. Main Build (`build.yml`)
- **Purpose**: Builds the complete STRATO platform on x86_64
- **Triggers**: Push to main/master, Pull Requests
- **What it does**:
  - Builds the buildbase Docker image
  - Compiles all Haskell components
  - Creates Docker images for all services
  - Generates docker-compose files
  - Tests basic functionality

### 2. ARM64 Test (`build-arm64.yml`)
- **Purpose**: Tests ARM64 compatibility for Apple Silicon
- **Triggers**: Push to main/master, Pull Requests
- **What it does**:
  - Tests ARM64 builds using QEMU emulation
  - Identifies packages with ARM64 compatibility issues
  - Reports on Apple Silicon readiness

## How to Use

### For Apple Silicon Users:
1. **Fork this repository** to your GitHub account
2. **Push changes** to trigger builds
3. **Download built images** from the Actions artifacts
4. **Run locally** using the generated docker-compose files

### Building Locally on Apple Silicon:
```bash
# Pull the pre-built x86_64 images
docker pull ghcr.io/YOUR_USERNAME/strato:latest
docker pull ghcr.io/YOUR_USERNAME/highway:latest
docker pull ghcr.io/YOUR_USERNAME/vault-wrapper:latest
docker pull ghcr.io/YOUR_USERNAME/identity-provider:latest

# Run using docker-compose
docker-compose up
```

## ARM64 Compatibility Status

Some packages may not build on ARM64 due to:
- C dependencies without ARM64 support
- Platform-specific optimizations
- Missing ARM64 configurations

This is normal for Haskell projects with native dependencies.

## Contributing

1. Fork this repository
2. Make your changes
3. Push to trigger GitHub Actions
4. Submit a pull request back to the original repository

## Benefits

- ✅ **Free builds** on GitHub Actions (2,000 minutes/month)
- ✅ **x86_64 compatibility** guaranteed
- ✅ **No local build issues** on Apple Silicon
- ✅ **Automated testing** on every push
- ✅ **Easy deployment** with pre-built images 