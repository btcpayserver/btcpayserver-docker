# DockerFile build helper

By default, when you use docker deployment, you are fetching pre-built docker images hosted on dockerhub.
While this bring the advantage that deployment is fast and reliable, this also mean that you are ultimately trusting the owner of the docker images.
This repository generate a script that you can use to build all images from the sources by yourself.

## How to use?

Install [.NET Core SDK](https://dotnet.microsoft.com/download) and run:

```bash
./run.sh
```

This will build a `build-all.sh` file.
Note that the 
