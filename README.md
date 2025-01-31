![logo](https://blockapps.net/wp-content/uploads/2025/01/STAKEABLE_GOLD_HALF.png)

# STRATO Platform

## Prerequisites to build

### Docker
Install the latest docker from https://www.docker.com/

- Docker Engine v.20.10+
- Docker Compose V2

### Stack
Stack v2.11.1 is required to build strato-platform with docker env enabled

Most unix systems (incl. ubuntu and mac):
```
curl -sSL https://get.haskellstack.org/ | sh
```

### MacOS ONLY - Docker for Mac setting requirements:
In Docker for Mac "Preferences" -> "Advanced" allocate at least *2 CPU cores, 6 Gb RAM and 2Gb Swap* to a Docker VM

## Build

### Config vars
1. `REPO` env var is required for the build.

    Possible values:
    - `local` (empty docker registry url)
    - `private` (`registry-aws.blockapps.net:5000/blockapps/` - BlockApps' private registry)
    - `public` (`registry-aws.blockapps.net:5000/blockapps-repo/` - BlockApps' public registry)

2. `REPO_URL` (discouraging to use) is optional and may be used to set custom docker registry URL (`REPO` var has more priority and will overridde `REPO_URL`'s value if both are provided)

3. `VERSION` (discouraging to use) is optional and may be used to override the version tag from VERSION file

### Build commands
-  Build all and generate docker-compose.yml:
    ```
    <CONFIG_VARS> make
    ```

- Only build one application (e.g. strato):
    ```
    <CONFIG_VARS> make strato
    ```

- Only generate docker-compose.yml (will overwrite the existing):
    ```
    <CONFIG_VARS> make docker-compose
    ```
### Debugging
- GHC/Stack provides a tool called "profiling" which allows you to create a report of how much memory and cycles a process is using for each function, etc. 
  [GHC Profiling](https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/profiling.html)
- Modify the `doit.sh` script so that the program you are profiling has the following args:

```
<progname> +RTS -p -h -RTS ...<args>
```

- Build strato with the `make build_common_profiled` command, then push the docker images using `make docker-build`
- Run strato in docker using the `./strato` command
- A `<progname>.prof` file will be created in the `var/lib/strato/` folder for you to analyze
### Plain `stack` usage for core-strato and bloc
Stack commands (like `stack build`, `stack test` etc.) can only be used once the buildbase image is built.

This is a part of main build process described in this readme but you can also build it manually by running
```make build_buildbase``` in `core-strato/` and `blockapps-haskell/` directories (for core-strato and bloc accordingly)

### Building the list of 3rd party dependencies and their licenses

#### NodeJS apps

```
npm i npm-license-crawler -g
```

E.g. for SMD:
```
cd strato-platform/smd-ui
npm-license-crawler  --omitVersion --onlyDirectDependencies --dependencies --csv smd.csv
```

#### Haskell apps

E.g. for core-strato:
```
cd strato-platform/core-strato
stack ls dependencies --license --no-include-base --depth 1
```

#### Other (binary installations etc)

TBD

## (**DEPRECATED** for docker-env stack builds) APPENDIX: Libraries used in build process

For the list of currenty used libraries see Dockerfile.multi for run-time libs and Dockerfile.buildbase for compilation lib requirements
These libraries are no longer required to be installed on the host since we use docker-enabled Stack. So we keep them here just in case:


#### Ubuntu/debian:

```
sudo apt-get install cmake libboost-all-dev libpq-dev libsodium-dev autoconf libleveldb-dev libsecp256k1-dev
```

#### Centos/RHEL/Amazon linux 2

```
sudo yum install http://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-11.noarch.rpm
sudo yum install libsodium libsodium-devel postgresql-devel cmake3 gcc-c++ libleveldb-devel libtool automake libz-devel libleveldb-devel libsecp256k1-dev
```
There are some additional awkward steps to have `cmake3` under a name that solidity can build with
and to install a compatible version of boost:
```
sudo ln -s /usr/bin/cmake3 /usr/local/bin/cmake
wget http://sourceforge.net/projects/boost/files/boost/1.67.0/boost_1_67_0.tar.gz
tar -xvzf boost_1_67_0.tar.gz
cd boost_1_67_0/
./bootstrap.sh
./b2
sudo ./b2 install
```

#### Mac people:

None library dependencies

#### (Should no longer occur): Known issue with 'happy' lib when building on host (non-docker-enabled stack)

Also we need to explicitly install `happy` library on the host:
```
stack install happy-1.19.5
```
possible reason for that is because some of the used libs uses it but doesn't have as a "build-tools" dependency in .cabal
(also see https://github.com/haskell/cabal/issues/4574)
