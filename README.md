![logo](https://blockapps.net/wp-content/uploads/2025/01/STAKEABLE_GOLD_HALF.png)

# STRATO Mercata platform (open source snapshot)

This is an open source snapshot of the STRATO Mercata platform, tools and applications.  It was released publicly in January 2025.

This is the first of many steps of a larger open sourcing project.  Future steps will see the decoupling of STRATO Mercata as a
platform and ecosystem from BlockApps Inc as a corporate entity, which will be reflected in branding, websites, social media
channels and in Github, where a new organization will be created, with code migrating across as the open sourcing and rebranding
progresses.

The core of STRATO is the Haskell Ethereum client software which was built in 2014, during the very early days of Ethereum prior
to mainnet launch.   This codebase was instrumental to the very first Blockchain-as-a-Service (BaaS) offering announced at
DEVCON1 in London in 2015 in collaboration with Microsoft, bringing blockchain nodes to Azure.

## Prerequisites to build

### Docker
Install the latest docker from https://www.docker.com/

- Docker Engine v.20.10+
- Docker Compose V2

### Stack
Stack v2.11.1+ is required to build strato-platform with docker env enabled

Most unix systems (incl. ubuntu and mac):
```
curl -sSL https://get.haskellstack.org/ | sh
```


### Build commands
-  Build all and generate docker-compose.yml:
    ```
    make
    ```

- Only build one application (e.g. strato):
    ```
    make strato
    ```

- Only generate docker-compose.yml (will overwrite the existing):
    ```
    make docker-compose
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

### Plain `stack` usage
Stack commands (like `stack build`, `stack test` etc.) can only be used once the buildbase image is built.

This is a part of main build process described in this readme but you can also build it manually by running
```make build_buildbase``` in the root directory.
