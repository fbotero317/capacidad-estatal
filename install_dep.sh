#!/bin/zsh

# Function to install with conda or pip fallback
install_package() {
    package_name=$1
    conda_package_name=$2
    pip_package_name=${3:-$2}

    echo "Installing $package_name..."
    # Try installing with conda first
    conda install -y "$conda_package_name" 2>/dev/null

    # Check if the installation was successful
    if [[ $? -ne 0 ]]; then
        echo "Conda installation failed for $package_name. Trying pip..."
        pip install "$pip_package_name"
    else
        echo "$package_name installed successfully with conda."
    fi
}

# Update conda and pip
echo "Updating conda and pip..."
conda update -n base -c defaults conda -y
pip install --upgrade pip

# Install dependencies
install_package "geopandas" "geopandas"
install_package "pandas" "pandas"
install_package "numpy" "numpy"
install_package "shapely" "shapely"
install_package "pyproj" "pyproj"
install_package "pyarrow" "pyarrow"
install_package "tqdm" "tqdm"
install_package "multiprocessing" "multiprocessing-logging" # Note: multiprocessing is part of Python's standard library

echo "All packages installed."

