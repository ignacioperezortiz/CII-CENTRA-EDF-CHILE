using CSV
using DataFrames
using CairoMakie
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket_sinLDES/"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Iterar sobre cada carpeta de escenario y procesar los archivos
for scenario in scenarios
    println("Processing scenario: $scenario")
    
    # Verificar si el directorio del escenario está vacío
    if isempty(readdir(scenario*"/outputs"))
        println("Skipping empty scenario: $scenario")
        continue
    end
    
    # Definir la ruta del archivo CSV para el escenario actual
    csv_file_path = joinpath(scenario, "outputs", "transmission.csv")
    
    # Cargar los datos desde el archivo CSV
    df = CSV.read(csv_file_path, DataFrame)
    
    # Filtrar las filas donde TRANSMISSION_LINE no contiene "Tx-" o "H2"
    filtered_df = filter(row -> !occursin("Tx-", row.TRANSMISSION_LINE) && !occursin("H2", row.TRANSMISSION_LINE), df)
    
    # Agrupar por PERIOD y sumar TxCapacityNameplate
    grouped_df = combine(groupby(filtered_df, :PERIOD), :TxCapacityNameplate => sum => :TotalTxCapacity)
    
    # Crear el gráfico
    fig = Figure(size = (800, 600))
    ax = Axis(fig[1, 1], title = "Total Transmission Capacity by Year", xlabel = "Year", ylabel = "Total Transmission Capacity (Nameplate)",
              titlesize = 24, xlabelsize = 18, ylabelsize = 18)
    
    # Establecer los límites del eje y
    ylims!(ax, 30000, 55000)
    
    lines!(ax, grouped_df.PERIOD, grouped_df.TotalTxCapacity)
    scatter!(ax, grouped_df.PERIOD, grouped_df.TotalTxCapacity, marker = :circle)
    
    # Guardar la figura en la ruta especificada
    save(joinpath(scenario, "Transmission/Total_Transmission_Capacity_by_Year.png"), fig)
    
    # Guardar el DataFrame resultante en un archivo CSV
    CSV.write(joinpath(scenario, "Transmission/Total_Transmission_Capacity_by_Year.csv"), grouped_df)
    
    # Mostrar la figura
    display(fig)
end

println("Processing complete.")