#!/bin/bash

# Read the file line by line
while IFS="=" read -r package version; do
    echo "Installing $package version $version"
    conda install -c r "r-$package=$version" -y
done < r_requirements.txt
