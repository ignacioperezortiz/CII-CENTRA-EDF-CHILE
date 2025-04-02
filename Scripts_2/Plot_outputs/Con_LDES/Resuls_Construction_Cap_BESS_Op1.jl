using CSV
using DataFrames
using CairoMakie
using PrettyTables
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/BESS_Construccion_Masiva2"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Definir colores para cada duración de almacenamiento
colors = Dict(
    1 => "#FFD700",    # Amarillo oscuro
    2 => "#4682B4",    # Azul acero (Steel Blue)
    4 => "#32CD32",    # Verde lima (Lime Green)
    6 => "#800080"     # Púrpura (para >4 horas)
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

    # Inicializar la columna Storage_Energy_GWh con ceros
    filtered_df.Storage_Energy_GWh = zeros(Float64, nrow(filtered_df))

    # Calcular Storage_Energy_GWh para cada fila (convertir MWh a GWh)
    for row in eachrow(filtered_df)
        project_info = df2[df2.GENERATION_PROJECT .== row.generation_project, :]
        if nrow(project_info) > 0
            storage_energy_ratio = project_info.gen_storage_energy_to_power_ratio[1]
            row.Storage_Energy_GWh = (row.GenCapacity_MW * storage_energy_ratio) / 1000  # Convertir MWh a GWh
        end
    end

    # Clasificar tecnologías ESS por duración de almacenamiento (1, 2, 4, 6 horas)
    filtered_df.storage_duration = [nrow(df2[df2.GENERATION_PROJECT .== row.generation_project, :]) > 0 ? classify_duration(df2[df2.GENERATION_PROJECT .== row.generation_project, :gen_storage_energy_to_power_ratio][1]) : missing for row in eachrow(filtered_df)]

    # Eliminar filas con valores faltantes en storage_duration
    filtered_df = dropmissing(filtered_df, :storage_duration)

    # Guardar el DataFrame resultante en un nuevo archivo CSV
    CSV.write(joinpath(scenario, "filtered_ess_data.csv"), filtered_df)

    # Crear tablas pivotadas para Storage_Energy_GWh y GenCapacity_GW, sumando valores para duplicados y agrupando por duración de almacenamiento
    pivot_df_energy = unstack(filtered_df, :period, :storage_duration, :Storage_Energy_GWh, combine=sum)
    pivot_df_capacity = unstack(filtered_df, :period, :storage_duration, :GenCapacity_MW, combine=sum)

    # Convertir GenCapacity_MW a GW en pivot_df_capacity
    for col in names(pivot_df_capacity)[2:end] # Excluye la columna 'period'
        pivot_df_capacity[!, col] = pivot_df_capacity[!, col] ./ 1000
    end
    period_energy = pivot_df_energy.period
    period_capacity = pivot_df_capacity.period
    pivot_df_energy2 = deepcopy(pivot_df_energy)
    for col in names(pivot_df_energy2)[2:end]
        pivot_df_energy2[2:end, col] = [pivot_df_energy2[i, col] - pivot_df_energy2[i-1, col] for i in 2:nrow(pivot_df_energy2)]
        pivot_df_energy2[1, col] = pivot_df_energy[1, col]
    end

    pivot_df_capacity2 = deepcopy(pivot_df_capacity)
     for col in names(pivot_df_capacity2)[2:end]
        pivot_df_capacity2[2:end, col] = [pivot_df_capacity2[i, col] - pivot_df_capacity2[i-1, col] for i in 2:nrow(pivot_df_capacity2)]
        pivot_df_capacity2[1, col] = pivot_df_capacity[1, col]
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
    CSV.write(joinpath(scenario, "ess_storage_Construction_capacity_gw.csv"), pivot_df_capacity2) #cambiado el nombre del archivo

    data_energy = pivot_df_energy2
    data_capacity = pivot_df_capacity2

    # Crear la figura y el eje para Storage_Energy_GWh
    fig_energy = Figure(size = (1000, 600))
    ax_energy = Axis(fig_energy[1, 1], title = "Capacidad construida de BESS (GWh) por Duración (Escenario: $(basename(scenario)))", xlabel = "Periodo", ylabel = "Capacidad de Almacenamiento (GWh)",
                        titlesize = 24, xlabelsize = 16, ylabelsize = 16)

    # Definir los periodos específicos
    periods = [2024, 2026, 2029, 2030, 2031, 2033, 2040, 2050]

    # Crear el gráfico de barras para Storage_Energy_GWh
    width = 0.2
    for i in 1:size(data_energy, 2)
        x_positions = 1:length(periods)
        barplot!(ax_energy, x_positions .+ ((i - length(duration_order) / 2) * width) .+ (width / 2), data_energy[:, i],
                 label = string(names(pivot_df_energy2)[i]), color = colors[parse(Int, names(pivot_df_energy2)[i])], width = width)
    end

    # Añadir leyenda
    legend_energy = Legend(fig_energy, ax_energy, "Duración", title = "Duración del Almacenamiento (Horas)", fontsize = 8)
    fig_energy[1, 2] = legend_energy

     # Asignar las posiciones de los ticks del eje X usando los periodos específicos
    ax_energy.xticks = (1:length(periods), string.(periods))
    # Definir los límites del eje X según los valores de los periodos
    xlims!(ax_energy, 0, length(periods) + 1)
    ax_energy.ylabelpadding = 40
    ylims!(ax_energy, 0, 25) # Establecer el límite superior del eje Y en 25 para GWh

    # Guardar la figura
    save(joinpath(scenario, "ess_Construction_bar_chart_storage_energy_gwh.png"), fig_energy) #cambiado el nombre del archivo
    display(fig_energy)

    # Crear la figura y el eje para GenCapacity_GW
    fig_capacity = Figure(size = (1000, 600))
    ax_capacity = Axis(fig_capacity[1, 1], title = "Capacidad construida de almacenamiento BESS (GW) por Duración (Escenario: $(basename(scenario)))", xlabel = "Periodo", ylabel = "Capacidad Instalada (GW)",
                          titlesize = 24, xlabelsize = 16, ylabelsize = 16)

    # Crear el gráfico de barras para GenCapacity_GW
    for i in 1:size(data_capacity, 2)
        x_positions = 1:length(periods)
        barplot!(ax_capacity, x_positions .+ ((i - length(duration_order) / 2) * width) .+ (width / 2), data_capacity[:, i],
                 label = string(names(pivot_df_capacity2)[i]), color = colors[parse(Int, names(pivot_df_capacity2)[i])], width = width)
    end

    # Añadir leyenda
    legend_capacity = Legend(fig_capacity, ax_capacity, "Duración", title = "Duración del Almacenamiento (Horas)", fontsize = 8)
    fig_capacity[1, 2] = legend_capacity

    # Asignar las posiciones de los ticks del eje X usando los periodos específicos
    ax_capacity.xticks = (1:length(periods), string.(periods))
    # Definir los límites del eje X según los valores de los periodos
    xlims!(ax_capacity, 0, length(periods) + 1)
    ax_capacity.ylabelpadding = 40
    ylims!(ax_capacity, 0, nothing)
    # Guardar la figura
    save(joinpath(scenario, "ess_Construction_bar_chart_installed_capacity_gw.png"), fig_capacity) #cambiado el nombre del archivo
    display(fig_capacity)
end

println("Processing complete.")
