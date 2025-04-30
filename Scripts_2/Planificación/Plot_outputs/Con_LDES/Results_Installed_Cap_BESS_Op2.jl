using CSV
using DataFrames
using CairoMakie
using PrettyTables
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/CasoBase"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Definir colores para cada duración de almacenamiento
colors = Dict(
    1 => "#FFD700",    # Amarillo oscuro
    2 => "#4682B4",    # Azul acero (Steel Blue)
    4 => "#32CD32",    # Verde lima (Lime Green)
    6 => "#800080"      # Púrpura (para >4 horas)
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
    println("Procesando escenario: $scenario")

    # Verificar si el directorio del escenario está vacío
    if isempty(readdir(joinpath(scenario, "outputs")) )
        println("Saltando escenario vacío: $scenario")
        continue
    end

    # Definir rutas de archivos para el escenario actual
    filename1 = joinpath(scenario, "outputs", "dispatch_gen_annual_summary.csv")
    filename2 = joinpath(scenario, "inputs", "gen_info.csv")

    # Leer los datos CSV en DataFrames, asegurando que las columnas se lean como cadenas de texto
    df1 = CSV.read(filename1, DataFrame; types=Dict(:gen_tech => String, :generation_project => String))
    df2 = CSV.read(filename2, DataFrame; types=Dict(:gen_tech => String, :GENERATION_PROJECT => String, :gen_storage_energy_to_power_ratio => String, :gen_tes_duration => String))

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
    pivot_df_energy = combine(groupby(filtered_df, [:period, :storage_duration]), :Storage_Energy_MWh => sum => :Storage_Energy_MWh)
    pivot_df_capacity = combine(groupby(filtered_df, [:period, :storage_duration]), :GenCapacity_MW => sum => :GenCapacity_MW)

    # Ordenar los DataFrames pivotados por período
    sort!(pivot_df_energy, :period)
    sort!(pivot_df_capacity, :period)

    # Definir los períodos específicos (2024, 2026, 2029, 2030, 2031, 2033, 2040, 2050)
    periods = [2024, 2026, 2029, 2030, 2031, 2033, 2040, 2050]

    # Filtrar los DataFrames para los períodos deseados
    pivot_df_energy = filter(row -> row.period in periods, pivot_df_energy)
    pivot_df_capacity = filter(row -> row.period in periods, pivot_df_capacity)

    # Crear las figuras para las gráficas apiladas
    fig_energy = Figure(size = (1000, 600))
    ax_energy = Axis(fig_energy[1, 1],
                    title = "Capacidad de Almacenamiento BESS (MWh) por Año (Scenario: $(basename(scenario)))",
                    xlabel = "Periodo",
                    ylabel = "Capacidad de Almacenamiento (MWh)",
                    xticks = (1:length(periods), string.(periods)),
                    titlesize = 24,
                    xlabelsize = 16,
                    ylabelsize = 16)

    fig_capacity = Figure(size = (1000, 600))
    ax_capacity = Axis(fig_capacity[1, 1],
                    title = "Capacidad Instalada de Almacenamiento BESS (MW) por Año (Scenario: $(basename(scenario)))",
                    xlabel = "Periodo",
                    ylabel = "Capacidad Instalada (MW)",
                    xticks = (1:length(periods), string.(periods)),
                    titlesize = 24,
                    xlabelsize = 16,
                    ylabelsize = 16)

    # Convertir la columna `storage_duration` a String para usarla como clave en el diccionario `colors`
    pivot_df_energy[!, :storage_duration] = string.(pivot_df_energy[!, :storage_duration])
    pivot_df_capacity[!, :storage_duration] = string.(pivot_df_capacity[!, :storage_duration])

    # Asegurar que los valores en la columna `storage_duration` sean enteros
    pivot_df_energy.storage_duration = parse.(Int64, pivot_df_energy.storage_duration)
    pivot_df_capacity.storage_duration = parse.(Int64, pivot_df_capacity.storage_duration)

    # Asegurar que los valores en la columna `storage_duration` sean cadenas
    unique_durations_energy = unique(pivot_df_energy.storage_duration)
    unique_durations_capacity = unique(pivot_df_capacity.storage_duration)

    # Imprimir las duraciones de almacenamiento únicas para verificar
    println("Duraciones de almacenamiento únicas para energía: ", unique_durations_energy)
    println("Duraciones de almacenamiento únicas para capacidad: ", unique_durations_capacity)

    # Map periods to numerical values for plotting
    period_mapping_energy = Dict(period => i for (i, period) in enumerate(periods))
    period_mapping_capacity = Dict(period => i for (i, period) in enumerate(periods))

    # Plot stacked bar chart for energy
    barplot_energy = if !isempty(pivot_df_energy)
        barplot!(ax_energy,
                 [period_mapping_energy[period] for period in pivot_df_energy.period],
                 pivot_df_energy.Storage_Energy_MWh,
                 stack = [duration for duration in pivot_df_energy.storage_duration],
                 color = [colors[duration] for duration in pivot_df_energy.storage_duration],
                 width = 0.5,
                 label = [string(dur) for dur in unique_durations_energy])
    else
        println("No hay datos de energía para graficar en el escenario: $(basename(scenario))")
        text!(ax_energy, "No hay datos de energía para graficar", position = (mean(1:length(periods)), 0), textsize = 16)
        # Agrega los años faltantes al eje x aunque no haya datos
        ax_energy.xticks = (1:length(periods), string.(periods))
        nothing
    end

    # Plot stacked bar chart for capacity
    barplot_capacity = if !isempty(pivot_df_capacity)
        barplot!(ax_capacity,
                 [period_mapping_capacity[period] for period in pivot_df_capacity.period],
                 pivot_df_capacity.GenCapacity_MW,
                 stack = [duration for duration in pivot_df_capacity.storage_duration],
                 color = [colors[duration] for duration in pivot_df_capacity.storage_duration],
                 width = 0.5,
                 label = [string(dur) for dur in unique_durations_capacity])
    else
        println("No hay datos de capacidad para graficar en el escenario: $(basename(scenario))")
        text!(ax_capacity, "No hay datos de capacidad para graficar", position = (mean(1:length(periods)), 0), textsize = 16)
        # Agrega los años faltantes al eje x aunque no haya datos
        ax_capacity.xticks = (1:length(periods), string.(periods))
        nothing
    end

    # Crear la leyenda con colores correctos
    if barplot_energy !== nothing
        Legend(fig_energy[1, 2],
              [PolyElement(color = colors[duration]) for duration in unique_durations_energy],
              string.("Duración (Horas) : ", unique_durations_energy);
              labelcolor = :black,
              labelsize = 12,
              titlecolor = :black,
              titlefont = 10)
    end

    if barplot_capacity !== nothing
        Legend(fig_capacity[1, 2],
              [PolyElement(color = colors[duration]) for duration in unique_durations_capacity],
              string.("Duración (Horas) : ", unique_durations_capacity);
              labelcolor = :black,
              labelsize = 12,
              titlecolor = :black,
              titlefont = 10)
    end

    # Guardar las figuras en la ruta especificada
    save(joinpath(scenario, "ess_annual_bar_chart_energy.png"), fig_energy)
    save(joinpath(scenario, "ess_annual_bar_chart_capacity.png"), fig_capacity)

    # Mostrar las figuras
    display(fig_energy)
    display(fig_capacity)
end

println("Procesamiento completo.")
