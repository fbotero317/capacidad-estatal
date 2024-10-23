import geopandas as gpd
import pandas as pd
import pyogrio
import os
from tqdm import tqdm
import requests
from pathlib import Path

# Set up paths and directories
output_path = Path(Path(__file__).parent.parent,'03_output')

# List of African countries (ISO 3166-1 alpha-3 codes)
countries = [
    'DZA', 'AGO', 'BEN', 'BWA', 'BFA', 'BDI', 'CMR', 'CPV', 'CAF', 'TCD', 
    'COM', 'COG', 'COD', 'DJI', 'EGY', 'GNQ', 'ERI', 'ETH', 'GAB', 'GMB', 
    'GHA', 'GIN', 'GNB', 'CIV', 'KEN', 'LSO', 'LBR', 'LBY', 'MDG', 'MWI', 
    'MLI', 'MRT', 'MUS', 'MAR', 'MOZ', 'NAM', 'NER', 'NGA', 'RWA', 'STP', 
    'SEN', 'SYC', 'SLE', 'SOM', 'ZAF', 'SSD', 'SDN', 'SWZ', 'TZA', 'TGO', 
    'TUN', 'UGA', 'ZMB', 'ZWE'
]

def download_file(url, filename):
    """Download a file with progress bar"""
    try:
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
    except requests.exceptions.RequestException as e:
        print(f"Error downloading {filename}: {str(e)}")
        return False
    return True

def process_gadm_data(country_code):
    """Download and process GADM data for a single country"""
    url = f"https://geodata.ucdavis.edu/gadm/gadm4.1/gpkg/gadm41_{country_code}.gpkg"
    output_file = output_path / f"gadm41_{country_code}.gpkg"
    
    try:
        if not output_file.exists():
            print(f"Downloading data for {country_code}...")
            if not download_file(url, output_file):
                return None
        
        # Read the geopackage, selecting only the first-level administrative divisions
        gdf = gpd.read_file(output_file, layer="ADM_ADM_1")
        return gdf
    
    except Exception as e:
        print(f"Error processing {country_code}: {str(e)}")
        return None

def main():
    # Create output directory if it doesn't exist
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Process all countries
    all_data = []
    failed_countries = []
    
    for country in tqdm(countries, desc="Processing countries"):
        country_data = process_gadm_data(country)
        if country_data is not None:
            all_data.append(country_data)
        else:
            failed_countries.append(country)
    
    if failed_countries:
        print(f"\nFailed to process the following countries: {', '.join(failed_countries)}")
    
    if not all_data:
        raise ValueError("No country data was successfully processed")
    
    # Combine all data
    print("\nCombining all country data...")
    africa = gpd.GeoDataFrame(pd.concat(all_data, ignore_index=True))
    
    # Project to EPSG:102022 (Africa Albers Equal Area Conic)
    print("Projecting to Africa Albers Equal Area Conic...")
    africa = africa.to_crs("esri:102022")
    
    # Calculate area
    print("Calculating areas...")
    africa['area_km2'] = africa.geometry.area / 1e6
    
    # Save the result
    output_file = output_path / "africa_admin_divisions.gpkg"
    print(f"\nSaving results to {output_file}")
    africa.to_file(output_file, driver="GPKG")
    print("Processing completed successfully!")
    
    return africa, failed_countries

if __name__ == '__main__':
    main()