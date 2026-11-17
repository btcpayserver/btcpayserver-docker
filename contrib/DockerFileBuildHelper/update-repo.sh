#!/bin/bash

dotnet run --no-launch-profile -c Release -- -omd "../../docs/supported-images.md"
