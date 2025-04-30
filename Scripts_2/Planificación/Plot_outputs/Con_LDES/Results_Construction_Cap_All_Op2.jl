using CSV
using DataFrames
using CairoMakie
using PrettyTables
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/BESS_Construccion_Masiva"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Definir colores para cada tecnología
colors = Dict(
    "Solar_FV" => "#FFD700",
    "Hidroelectrica" => "#4682B4",
    "Eolica" => "#32CD32",
    "Carbon" => "#696969",
    "Diesel" => "#A9A9A9",
    "GNL" => "#FF8C00",
    "Biomasa" => "#8B4513",
    "BESS" => "#800080",
    "Cogeneracion" => "#FF69B4",
    "Solar_CSP" => "#FFD700",
    "Geotermica" => "#DC143C",
    "Biogas" => "#00CED1",
    "PSP" => "#4169E1",
    "CAES" => "#006400",
    "TES" => "#000080"
)

# Iterar sobre cada carpeta de escenario y procesar los archivos
for scenario in scenarios
    println("Processing scenario: $scenario")

    # Verificar si el directorio del escenario está vacío
    if isempty(readdir(scenario * "/outputs"))
        println("Skipping empty scenario: $scenario")
        continue
    end

    # Definir rutas de archivos para el escenario actual
    filename = joinpath(scenario, "outputs", "dispatch_annual_summary.csv")

    # Leer los datos CSV en un DataFrame
    df = CSV.read(filename, DataFrame)

    # Crear la tabla pivotada
    pivot_df = unstack(df, :period, :gen_energy_source, :GenCapacity_MW)

    # Reemplazar los valores 'missing' por 0 en todas las columnas
    for col in names(pivot_df)
        replace!(pivot_df[!, col], missing => 0)
    end

    # Renombrar la columna 'ESS' a 'BESS'
    if "ESS" in names(pivot_df)
        rename!(pivot_df, "ESS" => "BESS")
    end

    # Renombrar la columna 'Bomb' a 'PSP'
    if "Bomb" in names(pivot_df)
        rename!(pivot_df, "Bomb" => "PSP")
    end

    # Ordenar las filas por 'period' de menor a mayor
    sort!(pivot_df, :period)

    # Sumar las columnas 'Solar-CSP' y 'Solar_CSP' y asignar el resultado a 'Solar_CSP'
    if "Solar-CSP" in names(pivot_df) && "Solar_CSP" in names(pivot_df)
        pivot_df.Solar_CSP .+= pivot_df."Solar-CSP"
        select!(pivot_df, Not(:"Solar-CSP"))
    end

    # Convertir los valores de MW a GW dividiendo por 1000
    for col in names(pivot_df)[2:end]
        pivot_df[!, col] ./= 1000
    end

    # Obtener el nombre de la columna 'period' para mantenerla como la primera
    period_column = :period

    # Obtener el resto de las columnas y ordenarlas en función del primer valor (de mayor a menor)
    other_columns = names(pivot_df)[2:end]
    sorted_columns = sort(other_columns, by = col -> pivot_df[1, Symbol(col)], rev = true)

    # Reorganizar las columnas, asegurando que 'period' esté al principio
    ordered_columns = vcat([period_column], sorted_columns)

    # Reordenar el DataFrame según las nuevas columnas
    pivot_df = pivot_df[:, Symbol.(ordered_columns)]

    # Mostrar el DataFrame resultante
    println(pivot_df)

    CSV.write(joinpath(scenario, "ICap.csv"), pivot_df)

    # Función para calcular el incremento anual
    function calculate_annual_increase(df::DataFrame, value_column::Symbol)
        result_df = DataFrame(period = Int64[], gen_tech = String[], increase = Float64[])
        unique_periods = unique(df.period)
        for i in 2:length(unique_periods)
            current_period = unique_periods[i]
            previous_period = unique_periods[i-1]
            current_data = df[df.period .== current_period, :]
            previous_data = df[df.period .== previous_period, :]
            for tech in names(df)[2:end] # Iterar sobre tecnologías (nombres de columnas)
                current_value = 0.0
                previous_value = 0.0

                # Buscar si la tecnología existe en el periodo actual
                if tech in names(current_data)
                    row_current = findfirst(names(current_data) .== tech)
                    if row_current !== nothing
                        current_value = current_data[1, tech] # Acceder al valor directamente por el nombre de la columna
                    end
                end

                # Buscar si la tecnología existe en el periodo anterior
                if tech in names(previous_data)
                    row_previous = findfirst(names(previous_data) .== tech)
                    if row_previous !== nothing
                        previous_value = previous_data[1, tech] # Acceder al valor directamente por el nombre de la columna
                    end
                end
                increase = current_value - previous_value
                if increase > 0
                    push!(result_df, (current_period, tech, increase))
                end
            end
        end
        return result_df
    end

    # Calcular el incremento anual para cada tecnología
    increase_df = calculate_annual_increase(pivot_df, :GenCapacity_MW)

    # Definir los períodos específicos (2024, 2026, 2029, 2030, 2031, 2033, 2040, 2050)
    periods = unique(increase_df.period)
    if !(2030 in periods)
        push!(periods, 2030)
    end
    sort!(periods)

    # Filtrar los DataFrames para los períodos deseados
    increase_df = filter(row -> row.period in periods, increase_df)

    # Crear las figuras para las gráficas apiladas
    fig = Figure(size = (1000, 600))
    ax = Axis(fig[1, 1],
        title = "Incremento Anual en Capacidad Instalada (GW) (Escenario: $(basename(scenario)))",
        xlabel = "Periodo",
        ylabel = "Incremento en Capacidad Instalada (GW)",
        xticks = (1:length(periods), string.(periods)),
        # Establecer el límite del eje y en 25
        limits = (nothing, nothing, nothing, 25),
        titlesize = 24,
        xlabelsize = 18,
        ylabelsize = 18)

    # Mapear períodos a valores numéricos para graficar
    period_mapping = Dict(period => i for (i, period) in enumerate(periods))

    # Obtener tecnologías únicas
    unique_techs = unique(increase_df.gen_tech)

    # Crear un diccionario que mapea tecnologías a posiciones enteras para el apilamiento
    tech_position_mapping = Dict(tech => i for (i, tech) in enumerate(unique_techs))

    # Agregar una nueva columna con la posición entera de la tecnología
    increase_df[:, :tech_position] = [tech_position_mapping[tech] for tech in increase_df.gen_tech]

    # Graficar la gráfica de barras apiladas
    # Asegurarse de que haya datos para graficar
    if nrow(increase_df) > 0
        barplot = barplot!(ax,
            [period_mapping[period] for period in increase_df.period],
            increase_df.increase,
            stack = increase_df.tech_position,
            color = [colors[tech] for tech in increase_df.gen_tech],
            width = 0.5,
            label = [string(tech) for tech in unique_techs])
    else
        # Si no hay datos, crear un gráfico vacío
        barplot = barplot!(ax, [period_mapping[2030]], [0], color = :transparent) #agrego el 2030
    end

    # Crear la leyenda con colores correctos
    Legend(fig[1, 2],
        [PolyElement(color = colors[tech]) for tech in unique_techs],
        string.("Tecnología: ", unique_techs);
        labelcolor = :black,
        labelsize = 12,
        titlecolor = :black,
        titlefont = 10)

    # Guardar la figura en la ruta especificada
    save(joinpath(scenario, "Icap_stacked_bar_chart_increase.png"), fig)

    # Mostrar la figura
    display(fig)
end

println("Procesamiento completo.")
