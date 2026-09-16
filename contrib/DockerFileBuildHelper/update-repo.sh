#!/bin/bash

dotnet run --no-launch-profile -c Release -- -o "../build-all-images.sh" -omd "../../docs/supported-images.md"
