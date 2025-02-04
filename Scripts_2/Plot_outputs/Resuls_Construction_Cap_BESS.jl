using CSV
using DataFrames
using CairoMakie
using PrettyTables
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Definir colores para cada duración de almacenamiento
colors = Dict(
    1 => "#FFD700",  # Amarillo oscuro
    2 => "#4682B4",  # Azul acero (Steel Blue)
    4 => "#32CD32",  # Verde lima (Lime Green)
    6 => "#800080"  # Púrpura (para >4 horas)
)

# Definir el orden de las duraciones de almacenamiento para graficar
duration_order = [1, 2, 4, 6]

# Función para clasificar la duración del almacenamiento
function classify_duration(duration)
    if duration <= 1
        return 1
    elseif duration <= 2
        return 2
    elseif duration <= 4
        return 4
    else
        return 6
    end
end

# Iterar sobre cada carpeta de escenario y procesar los archivos
for scenario in scenarios
    println("Processing scenario: $scenario")
    
    # Verificar si el directorio del escenario está vacío
    if isempty(readdir(joinpath(scenario, "outputs")))
        println("Skipping empty scenario: $scenario")
        continue
    end
    
    # Definir rutas de archivos para el escenario actual
    filename1 = joinpath(scenario, "outputs", "dispatch_gen_annual_summary.csv")
    filename2 = joinpath(scenario, "inputs", "gen_info.csv")
    
    # Leer los datos CSV en DataFrames, asegurando que las columnas se lean como cadenas de texto
    df1 = CSV.read(filename1, DataFrame; types=Dict(:gen_tech => String, :generation_project => String))
    df2 = CSV.read(filename2, DataFrame; types=Dict(:gen_tech => String, :GENERATION_PROJECT => String, :gen_storage_energy_to_power_ratio => String))
    
    # Reemplazar "." en gen_storage_energy_to_power_ratio con valores de gen_tes_duration si están disponibles
    for row in eachrow(df2)
        if row.gen_storage_energy_to_power_ratio == "."
            if row.gen_tes_duration != "."
                row.gen_storage_energy_to_power_ratio = row.gen_tes_duration
            end
        end
    end

    # Convertir la columna gen_storage_energy_to_power_ratio a Float64, reemplazando "." por 17
    df2.gen_storage_energy_to_power_ratio = [x == "." ? 17.0 : parse(Float64, x) for x in df2.gen_storage_energy_to_power_ratio]
    
    # Filtrar df2 para incluir solo tecnologías ESS
    df2 = filter(row -> row.gen_tech == "ESS", df2)
    
    # Filtrar df1 para incluir solo tecnologías ESS
    filtered_df = filter(row -> row.gen_tech == "ESS", df1)

    # Renombrar la columna 'ESS' a 'BESS'
    if "ESS" in names(filtered_df)
        rename!(filtered_df, "ESS" => "BESS")
    end
    
    # Inicializar la columna Storage_Energy_MWh con ceros
    filtered_df.Storage_Energy_MWh = zeros(Float64, nrow(filtered_df))
    
    # Calcular Storage_Energy_MWh para cada fila
    for row in eachrow(filtered_df)
        project_info = df2[df2.GENERATION_PROJECT .== row.generation_project, :]
        if nrow(project_info) > 0
            storage_energy_ratio = project_info.gen_storage_energy_to_power_ratio[1]
            row.Storage_Energy_MWh = row.GenCapacity_MW * storage_energy_ratio
        end
    end
    
    # Clasificar tecnologías ESS por duración de almacenamiento (1, 2, 4, 6 horas)
    filtered_df.storage_duration = [nrow(df2[df2.GENERATION_PROJECT .== row.generation_project, :]) > 0 ? classify_duration(df2[df2.GENERATION_PROJECT .== row.generation_project, :gen_storage_energy_to_power_ratio][1]) : missing for row in eachrow(filtered_df)]
    
    # Eliminar filas con valores faltantes en storage_duration
    filtered_df = dropmissing(filtered_df, :storage_duration)
    
    # Guardar el DataFrame resultante en un nuevo archivo CSV
    CSV.write(joinpath(scenario, "filtered_ess_data.csv"), filtered_df)
    
    # Crear tablas pivotadas para Storage_Energy_MWh y GenCapacity_MW, sumando valores para duplicados y agrupando por duración de almacenamiento
    pivot_df_energy = unstack(filtered_df, :period, :storage_duration, :Storage_Energy_MWh, combine=sum)
    pivot_df_capacity = unstack(filtered_df, :period, :storage_duration, :GenCapacity_MW, combine=sum)
    period_energy = pivot_df_energy.period
    period_capacity = pivot_df_capacity.period
    pivot_df_energy2 = deepcopy(pivot_df_energy)
    for col in names(pivot_df_energy2)[2:end]
        pivot_df_energy2[2:end, col] = [pivot_df_energy2[i, col] - pivot_df_energy2[i-1, col] for i in 2:nrow(pivot_df_energy2)]
        pivot_df_energy2[1, col] = pivot_df_energy[1, col]  # Mantener el primer valor igual al original
    end
    pivot_df_capacity2 = deepcopy(pivot_df_capacity)
    for col in names(pivot_df_capacity2)[2:end]
        pivot_df_capacity2[2:end, col] = [pivot_df_capacity2[i, col] - pivot_df_capacity2[i-1, col] for i in 2:nrow(pivot_df_capacity2)]
        pivot_df_capacity2[1, col] = pivot_df_capacity[1, col]  # Mantener el primer valor igual al original
    end

    # Ordenar las filas por 'period' de menor a mayor
    sort!(pivot_df_energy2, :period)
    sort!(pivot_df_capacity2, :period)
    
    # Reordenar las columnas según duration_order
    pivot_df_energy2 = pivot_df_energy2[!, [:"1", :"2", :"4", :"6"]]
    pivot_df_capacity2 = pivot_df_capacity2[!, [:"1", :"2", :"4", :"6"]]

    rename!(pivot_df_energy2, Dict(Symbol("1") => Symbol("1"), Symbol("2") => Symbol("2"), Symbol("4") => Symbol("4"), Symbol("6") => Symbol("6")))
    rename!(pivot_df_capacity2, Dict(Symbol("1") => Symbol("1"), Symbol("2") => Symbol("2"), Symbol("4") => Symbol("4"), Symbol("6") => Symbol("6")))
    
    # Guardar las tablas pivotadas en nuevos archivos CSV
    CSV.write(joinpath(scenario, "ess_storage_Construction_capacity_energy.csv"), pivot_df_energy2)
    CSV.write(joinpath(scenario, "ess_storage_Construction_capacity_mw.csv"), pivot_df_capacity2)

    data_energy = pivot_df_energy2
    data_capacity = pivot_df_capacity2
    
    # Crear la figura y el eje con proporciones ajustadas para Storage_Energy_MWh
    fig_energy = Figure(size = (1000, 600))  # Aumentar el ancho de la figura
    ax_energy = Axis(fig_energy[1, 1], title = "Capacidad construida de BESS (MWh) por Duración (Scenario: $(basename(scenario)))", xlabel = "Periodo", ylabel = "Capacidad de Almacenamiento (MWh)",
                     titlesize = 24, xlabelsize = 16, ylabelsize = 16)
    
    # Crear el gráfico de barras para Storage_Energy_MWh
    width = 0.2  # Ancho de cada barra (aumentado)
    for i in 1:size(data_energy, 2)
        barplot!(ax_energy, period_energy .+ ((i - length(duration_order) / 2) * width) .+ (width / 2), data_energy[:, i], label = string(names(pivot_df_energy2)[i]), color = colors[parse(Int, names(pivot_df_energy2)[i])], width = width)
    end
    
    # Añadir leyenda fuera del gráfico, a la derecha y reducir el tamaño de la simbología
    legend_energy = Legend(fig_energy, ax_energy, "Simbología", title = "Duración del Almacenamiento (Horas)", fontsize = 8)
    fig_energy[1, 2] = legend_energy
    
    # Añadir xticks de 5 en 5
    ax_energy.xticks = 1:5:maximum(period_energy)
    
    # Definir los límites del eje x como el valor mínimo y máximo de los periodos a graficar, con espacio adicional
    x_min = minimum(period_energy) - 1
    x_max = maximum(period_energy) + 1
    xlims!(ax_energy, x_min, x_max)
    
    # Ajustar la posición del título del eje Y para dar más espacio a los ticks del eje Y
    ax_energy.ylabelpadding = 40
    
    # Establecer el límite inferior del eje Y siempre en 0
    ylims!(ax_energy, 0, nothing)

    # Guardar la figura en la ruta especificada
    save(joinpath(scenario, "ess_Construction_bar_chart_storage_energy.png"), fig_energy)
    
    # Mostrar la figura
    display(fig_energy)
    
    # Crear la figura y el eje con proporciones ajustadas para GenCapacity_MW
    fig_capacity = Figure(size = (1000, 600))  # Aumentar el ancho de la figura
    ax_capacity = Axis(fig_capacity[1, 1], title = "Capacidad construida de almacenamiento BESS (MW) por Duración (Scenario: $(basename(scenario)))", xlabel = "Periodo", ylabel = "Capacidad Instalada (MW)",
                        titlesize = 24, xlabelsize = 16, ylabelsize = 16)
    
    # Crear el gráfico de barras para GenCapacity_MW
    for i in 1:size(data_capacity, 2)
        barplot!(ax_capacity, period_capacity .+ ((i - length(duration_order) / 2) * width) .+ (width / 2), data_capacity[:, i], label = string(names(pivot_df_capacity2)[i]), color = colors[parse(Int, names(pivot_df_capacity2)[i])], width = width)
    end
    
    # Añadir leyenda fuera del gráfico, a la derecha y reducir el tamaño de la simbología
    legend_capacity = Legend(fig_capacity, ax_capacity, "Simbología", title = "Duración del Almacenamiento (Horas)", fontsize = 8)
    fig_capacity[1, 2] = legend_capacity
    
    # Añadir xticks de 5 en 5
    ax_capacity.xticks = 1:5:maximum(period_capacity)
    
    # Definir los límites del eje x como el valor mínimo y máximo de los periodos a graficar, con espacio adicional
    x_min = minimum(period_capacity) - 1
    x_max = maximum(period_capacity) + 1
    xlims!(ax_capacity, x_min, x_max)
    
    # Ajustar la posición del título del eje Y para dar más espacio a los ticks del eje Y
    ax_capacity.ylabelpadding = 40
    
    # Establecer el límite inferior del eje Y siempre en 0
    ylims!(ax_capacity, 0, nothing)
    
    # Guardar la figura en la ruta especificada
    save(joinpath(scenario, "ess_Construction_bar_chart_installed_capacity.png"), fig_capacity)
    
    # Mostrar la figura
    display(fig_capacity)
end

println("Processing complete.")