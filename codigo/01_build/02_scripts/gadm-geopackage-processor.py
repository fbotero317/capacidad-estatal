import geopandas as gpd
import pandas as pd
import pyogrio
import os
from tqdm import tqdm
import requests
from pathlib import Path

# Set up paths and directories
output_path = Path(Path(__file__).parent.parent,'03_output')

# List of Latin American countries (ISO 3166-1 alpha-3 codes)
countries = ['ARG', 'BOL', 'BRA', 'CHL', 'COL', 'ECU', 'GUF','GUY', 'PRY', 'PER', 'SUR', 'URY', 'VEN']

def download_file(url, filename):
    with requests.get(url, stream=True) as r:
        r.raise_for_status()
        total_size = int(r.headers.get('content-length', 0))
        with open(filename, 'wb') as f, tqdm(
            desc=str(filename),
            total=total_size,
            unit='iB',
            unit_scale=True,
            unit_divisor=1024,
        ) as progress_bar:
            for chunk in r.iter_content(chunk_size=8192):
                size = f.write(chunk)
                progress_bar.update(size)

# Function to download and process GADM data
def process_gadm_data(country_code):
    url = f"https://geodata.ucdavis.edu/gadm/gadm4.1/gpkg/gadm41_{country_code}.gpkg"
    output_file = output_path / f"gadm41_{country_code}.gpkg" 
    if not os.path.exists(output_file):
        # Download the data
        download_file(url, output_file)
    
    # Read the geopackage, selecting only the first-level administrative divisions
    gdf = gpd.read_file(output_file, layer="ADM_ADM_1")
    return gdf

# Process all countries
all_data = []
for country in tqdm(countries, desc="Processing countries"):
    country_data = process_gadm_data(country)
    all_data.append(country_data)

# Combine all data
latin_america = gpd.GeoDataFrame(pd.concat(all_data, ignore_index=True))

# Project to EPSG:102033 (South America Albers Equal Area Conic)
latin_america = latin_america.to_crs("esri:102033")

# Calculate area
latin_america['area_km2'] = latin_america.geometry.area / 1e6

# Save the result
latin_america.to_file(f"{output_path}/latin_america_admin_divisions.gpkg", driver="GPKG")
