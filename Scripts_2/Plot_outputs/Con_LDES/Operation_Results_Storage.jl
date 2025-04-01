using CSV
using DataFrames
using CairoMakie
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/"

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
    
    # Leer el archivo storage_dispatch.csv
    dispatch_file = joinpath(scenario, "outputs", "storage_dispatch.csv")
    if !isfile(dispatch_file)
        println("Skipping missing dispatch file in scenario: $scenario")
        continue
    end
    
    data = CSV.read(dispatch_file, DataFrame)
    
    # Extraer el año, día y la hora de la columna timepoint
    data.year = [split(tp, "-")[1] for tp in data.timepoint]
    data.day = [split(tp, "-")[2] for tp in data.timepoint]
    data.hour = [parse(Int, split(tp, "-")[4][1:2]) for tp in data.timepoint]
    
    # Agrupar por año, día y hora y sumar StateOfCharge, ChargeMW y DischargeMW para cada grupo
    grouped = combine(groupby(data, [:year, :day, :hour]), :StateOfCharge => sum, :ChargeMW => sum, :DischargeMW => sum)
    
    # Obtener las combinaciones únicas de año y día
    unique_year_days = unique(grouped[:, [:year, :day]])
    
    # Crear gráficos para cada combinación de año y día
    for row in eachrow(unique_year_days)
        year = row.year
        day = row.day
        day_data = grouped[(grouped.year .== year) .& (grouped.day .== day), :]
        
        fig = Figure(resolution = (800, 1200)) # Ajustar la resolución para acomodar tres gráficos
        ax1 = Axis(fig[1, 1], title = "State of Charge for $year-$day (Scenario: $(basename(scenario)))", xlabel = "Hour", ylabel = "State of Charge (MWh)")
        ax2 = Axis(fig[2, 1], title = "Charge Power for $year-$day (Scenario: $(basename(scenario)))", xlabel = "Hour", ylabel = "Charge Power (MW)")
        ax3 = Axis(fig[3, 1], title = "Discharge Power for $year-$day (Scenario: $(basename(scenario)))", xlabel = "Hour", ylabel = "Discharge Power (MW)")
        
        scatter!(ax1, day_data.hour, day_data.StateOfCharge_sum, marker = :circle)
        lines!(ax1, day_data.hour, day_data.StateOfCharge_sum)
        scatter!(ax2, day_data.hour, day_data.ChargeMW_sum, marker = :circle, color = :green)
        lines!(ax2, day_data.hour, day_data.ChargeMW_sum, color = :green)
        scatter!(ax3, day_data.hour, day_data.DischargeMW_sum, marker = :circle, color = :red)
        lines!(ax3, day_data.hour, day_data.DischargeMW_sum, color = :red)
        
        # Definir los límites del eje x como el valor mínimo y máximo de las horas a graficar
        x_min = minimum(day_data.hour)
        x_max = maximum(day_data.hour)
        xlims!(ax1, x_min, x_max)
        xlims!(ax2, x_min, x_max)
        xlims!(ax3, x_min, x_max)
        
        # Ajustar la posición del título del eje Y para dar más espacio a los ticks del eje Y
        ax1.ylabelpadding = 40
        ax2.ylabelpadding = 40
        ax3.ylabelpadding = 40
        
        linkxaxes!(ax1, ax2, ax3) # Compartir el eje x entre los tres gráficos
        
        # Guardar la figura en la ruta especificada
        output_dir = joinpath(scenario, "Storage_operation")
        mkpath(output_dir)
        save(joinpath(output_dir, "StateOfCharge_Charge_Discharge_$year-$day.png"), fig)
    end
end

println("Processing complete.")