# -*- coding: utf-8 -*-
import pandas as pd
from calendar import monthrange
from datetime import date
import os

# --- Configuration ---
# Adjust this path to match the location of your CSV file
CAPACITY_FACTOR_INPUT_FILE = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Operacion/escenarios/CasoBase_N/CN/variable_capacity_factors_sin_cuatridias.csv"

# --- Helper Function ---

def parse_timepoint_for_year(timepoint_str):
    """
    Parses the timepoint string (YYYYMMDDHH) and returns the year.
    Returns None if the format is invalid or the year cannot be extracted.
    """
    if not isinstance(timepoint_str, str) or len(timepoint_str) != 10:
        return None
    try:
        year_tp = int(timepoint_str[0:4])
        # Basic validation for a plausible year range (optional)
        if not (1900 <= year_tp <= 2100):
             return None
        # We only need the year, so no need to parse month/day/hour fully
        # unless stricter validation is required.
        return year_tp
    except (ValueError, TypeError):
        return None

# --- Main Logic ---

print(f"Attempting to read file: {CAPACITY_FACTOR_INPUT_FILE}")

# Check if the file exists
if not os.path.exists(CAPACITY_FACTOR_INPUT_FILE):
    print(f"Error: File not found at '{CAPACITY_FACTOR_INPUT_FILE}'")
else:
    try:
        # Read the CSV file
        df = pd.read_csv(CAPACITY_FACTOR_INPUT_FILE)
        print("File read successfully.")

        # Check for required columns
        required_cols = ['timepoint', 'GENERATION_PROJECT']
        if not all(col in df.columns for col in required_cols):
            missing_cols = [col for col in required_cols if col not in df.columns]
            print(f"Error: Missing required columns: {missing_cols}")
        else:
            print("Required columns found.")
            # Ensure timepoint is string type before parsing
            df['timepoint'] = df['timepoint'].astype(str)

            # Extract the year from the timepoint column
            print("Extracting year from timepoint...")
            df['year'] = df['timepoint'].apply(parse_timepoint_for_year)

            # Drop rows where year extraction failed
            original_rows = len(df)
            df = df.dropna(subset=['year'])
            valid_rows = len(df)
            print(f"Removed {original_rows - valid_rows} rows with invalid timepoint format.")

            if valid_rows > 0:
                # Convert year column to integer
                df['year'] = df['year'].astype(int)

                # Group by year and count unique generators
                print("/nCounting unique generators per year...")
                generator_counts = df.groupby('year')['GENERATION_PROJECT'].nunique()

                # Print the results
                if not generator_counts.empty:
                    print("-" * 30)
                    print("Unique Generators per Year:")
                    print("-" * 30)
                    for year, count in generator_counts.items():
                        print(f"Year {year}: {count} unique generators")
                    print("-" * 30)
                else:
                    print("No valid year data found to count generators.")
            else:
                print("No rows with valid years found after parsing.")

    except FileNotFoundError:
        # This case is handled by the initial os.path.exists check,
        # but kept here for robustness.
        print(f"Error: File not found at '{CAPACITY_FACTOR_INPUT_FILE}'")
    except pd.errors.EmptyDataError:
        print(f"Error: The file '{CAPACITY_FACTOR_INPUT_FILE}' is empty.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

print("/nScript finished.")
