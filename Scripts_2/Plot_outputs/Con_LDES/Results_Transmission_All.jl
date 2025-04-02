# Import necessary libraries
using CSV
using DataFrames
using CairoMakie
using FilePathsBase # Ensure this is installed or use standard path functions

# Define the base directory containing scenario folders
# IMPORTANT: Replace with your actual path
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/CasoBase/"

# Get a list of scenario directories within the base directory
# Filters out files, keeping only directories
scenarios = filter(isdir, readdir(base_dir, join=true))

# Iterate over each scenario directory
for scenario in scenarios
    println("Processing scenario: $scenario")

    escenario = scenario[end-1:end]

    # Define the path to the outputs subdirectory
    output_dir = joinpath(scenario, "outputs")

    # Check if the output directory exists and is not empty
    if !isdir(output_dir) || isempty(readdir(output_dir))
        println("Skipping scenario due to missing or empty outputs directory: $scenario")
        continue
    end

    # Define the full path to the transmission CSV file
    csv_file_path = joinpath(output_dir, "transmission.csv")

    # Check if the CSV file exists
    if !isfile(csv_file_path)
        println("Skipping scenario due to missing transmission.csv file: $scenario")
        continue
    end

    # --- Data Loading and Processing ---
    try
        # Load data from the CSV file into a DataFrame
        df = CSV.read(csv_file_path, DataFrame)

        # Filter out rows where TRANSMISSION_LINE contains "Tx-" or "H2"
        filtered_df = filter(row -> !occursin("Tx-", row.TRANSMISSION_LINE) && !occursin("H2", row.TRANSMISSION_LINE), df)

        # Check if filtered_df is empty after filtering
        if isempty(filtered_df)
            println("Skipping scenario due to no relevant data after filtering: $scenario")
            continue
        end

        # Group by PERIOD, sum TxCapacityNameplate, and convert to Gigawatts (GW)
        # Divide the sum by 1000 for the conversion
        grouped_df = combine(groupby(filtered_df, :PERIOD), :TxCapacityNameplate => sum => :TotalTxCapacity_GW)
        grouped_df.TotalTxCapacity_GW = grouped_df.TotalTxCapacity_GW / 1000.0

        # --- Plotting ---
        # Create a new figure for the plot
        fig = Figure(size = (800, 600))

        # Add an axis to the figure with updated title and labels for GW
        ax = Axis(fig[1, 1],
                  title = "Capacidad de transmisión total, Escenario: $escenario",
                  xlabel = "Periodo",
                  ylabel = "Capacidad de transmisión total (GW)", # Updated Y-axis label
                  titlesize = 24,
                  xlabelsize = 18,
                  ylabelsize = 18)

        # Set the y-axis limits (adjusted for GW)
        # Original limits (30000, 55000) divided by 1000
        ylims!(ax, 30, 55) # Adjusted limits for GW

        # Plot the total capacity (in GW) over the years as a line plot
        lines!(ax, grouped_df.PERIOD, grouped_df.TotalTxCapacity_GW)

        # Add scatter points to the line plot
        scatter!(ax, grouped_df.PERIOD, grouped_df.TotalTxCapacity_GW, marker = :circle)

        # --- Saving Results ---
        # Define the output path for the plot image
        plot_save_path = joinpath(scenario, "Total_Transmission_Capacity_by_Year_GW.png") # Added _GW to filename
        # Save the figure as a PNG image
        save(plot_save_path, fig)
        println("Plot saved to: $plot_save_path")

        # Define the output path for the results CSV
        csv_save_path = joinpath(scenario, "Total_Transmission_Capacity_by_Year_GW.csv") # Added _GW to filename
        # Save the resulting DataFrame (with GW values) to a CSV file
        CSV.write(csv_save_path, grouped_df)
        println("Data saved to: $csv_save_path")

        # Display the figure (optional, depending on the environment)
        # display(fig) # Uncomment if running in an environment that supports displaying plots

    catch e
        println("Error processing scenario $scenario: $e")
        # Optionally, print stacktrace for more details:
        # Base.showerror(stdout, e, Base.catch_backtrace())
    end
end

println("Processing complete.")
