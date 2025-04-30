using CSV
using DataFrames
using CairoMakie
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/CasoBase"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Iterar sobre cada carpeta de escenario y procesar los archivos
for scenario in scenarios
    println("Processing scenario: $scenario")
    
    # Verificar si el directorio del escenario está vacío
    if isempty(readdir(scenario * "/outputs"))
        println("Skipping empty scenario: $scenario")
        continue
    end
    
    # Definir la ruta del archivo CSV para el escenario actual
    csv_file_path = joinpath(scenario, "outputs", "transmission.csv")
    
    # Cargar los datos desde el archivo CSV
    df = CSV.read(csv_file_path, DataFrame)
    
    # Filtrar las filas donde TRANSMISSION_LINE no contiene "Tx-" o "H2"
    filtered_df = filter(row -> !occursin("Tx-", row.TRANSMISSION_LINE) && !occursin("H2", row.TRANSMISSION_LINE), df)
    
    # Agrupar por TRANSMISSION_LINE y crear un gráfico para cada línea
    grouped_lines = groupby(filtered_df, :TRANSMISSION_LINE)
    for group in grouped_lines
        line_name = group.TRANSMISSION_LINE[1]
        fig = Figure(size = (1200, 800))
        ax = Axis(fig[1, 1], title = "Transmission capacity, Line: $line_name, (Scenario: $(basename(scenario)))", xlabel = "Year", ylabel = "Transmission Capacity (Nameplate)", 
                  titlesize = 24, xlabelsize = 18, ylabelsize = 18)
        
        min_period = minimum(group.PERIOD)
        max_period = maximum(group.PERIOD)
        
        scatter!(ax, group.PERIOD, group.TxCapacityNameplate, label = line_name, marker = :circle, markersize = 10)
        lines!(ax, group.PERIOD, group.TxCapacityNameplate, linewidth = 2)
        
        xlims!(ax, min_period, max_period)
        
        # display(fig)
        
        # Guardar la figura en la ruta especificada
        output_dir = joinpath(scenario, "Transmission")
        mkpath(output_dir)
        save(joinpath(output_dir, "T_Cap_$line_name.png"), fig)
        
        # Guardar el DataFrame resultante en un archivo CSV para cada línea de transmisión
        CSV.write(joinpath(output_dir, "T_Cap_$line_name.csv"), group)
    end
    
    # Guardar el DataFrame filtrado en un archivo CSV
    CSV.write(joinpath(scenario, "Transmission/Transmission_Capacity_by_Line_and_Year.csv"), filtered_df)
end

println("Processing complete.")