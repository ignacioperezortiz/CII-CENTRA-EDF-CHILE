using CSV
using DataFrames
using CairoMakie
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/CasoBase/"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Iterar sobre cada carpeta de escenario y procesar los archivos
for scenario in scenarios
    println("Procesando escenario: $scenario")
    
    # Verificar si el directorio del escenario está vacío
    if isempty(readdir(scenario * "/outputs"))
        println("Saltando escenario vacío: $scenario")
        continue
    end
    
    # Leer el archivo storage_dispatch.csv
    dispatch_file = joinpath(scenario, "outputs", "storage_dispatch.csv")
    if !isfile(dispatch_file)
        println("Saltando archivo dispatch faltante en escenario: $scenario")
        continue
    end
    
    data = CSV.read(dispatch_file, DataFrame)
    
    # Filtrar las filas que contienen "Bomb" en la columna generation_project
    data = filter(row -> occursin("Bomb", row.generation_project), data)
    
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
        
        fig = Figure(resolution = (800, 1200))  # Ajustar la resolución para acomodar tres gráficos
        ax1 = Axis(fig[1, 1], title = "Estado de Carga PSP para $year-$day (Escenario: $(basename(scenario)))", xlabel = "Hora", ylabel = "Estado de Carga (MWh)")
        ax2 = Axis(fig[2, 1], title = "Potencia de Carga PSP para $year-$day (Escenario: $(basename(scenario)))", xlabel = "Hora", ylabel = "Potencia de Carga (MW)")
        ax3 = Axis(fig[3, 1], title = "Potencia de Descarga PSP para $year-$day (Escenario: $(basename(scenario)))", xlabel = "Hora", ylabel = "Potencia de Descarga (MW)")
        
        min_hour = minimum(day_data.hour)
        max_hour = maximum(day_data.hour.*4)
        
        scatter!(ax1, day_data.hour.*4, day_data.StateOfCharge_sum, marker = :circle)
        lines!(ax1, day_data.hour.*4, day_data.StateOfCharge_sum)
        scatter!(ax2, day_data.hour.*4, day_data.ChargeMW_sum, marker = :circle, color = :green)
        lines!(ax2, day_data.hour.*4, day_data.ChargeMW_sum, color = :green)
        scatter!(ax3, day_data.hour.*4, day_data.DischargeMW_sum, marker = :circle, color = :red)
        lines!(ax3, day_data.hour.*4, day_data.DischargeMW_sum, color = :red)
        
        xlims!(ax1, min_hour, max_hour)
        xlims!(ax2, min_hour, max_hour)
        xlims!(ax3, min_hour, max_hour)
        
        linkxaxes!(ax1, ax2, ax3)  # Compartir el eje x entre los tres gráficos
        
        # Guardar la figura en la ruta especificada
        output_dir = joinpath(scenario, "Storage_operation")
        mkpath(output_dir)
        save(joinpath(output_dir, "PSP_EstadoDeCarga_Carga_Descarga_$year-$day.png"), fig)
    end
end

println("Procesamiento completo.")
