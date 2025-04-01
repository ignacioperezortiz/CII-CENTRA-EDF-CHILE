using CSV
using DataFrames
using CairoMakie
using PrettyTables
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/Entrada_Ampliacion_Transmision"

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

    # Definir los períodos específicos (2024, 2026, 2029, 2030, 2031, 2033, 2040, 2050)
    periods = unique(pivot_df.period)

    # Filtrar los DataFrames para los períodos deseados
    filtered_df = filter(row -> row.period in periods, pivot_df)

    # Crear las figuras para las gráficas apiladas
    fig = Figure(size = (1000, 600))
    ax = Axis(fig[1, 1],
        title = "Capacidad Instalada Total (GW) por Año (Escenario: $(basename(scenario)))",
        xlabel = "Periodo",
        ylabel = "Capacidad Instalada (GW)",
        xticks = (1:length(periods), string.(periods)),
        # Establecer el límite del eje y en 100
        limits = (nothing, nothing, nothing, 100),
        titlesize = 24,
        xlabelsize = 18,
        ylabelsize = 18)

    # Mapear períodos a valores numéricos para graficar
    period_mapping = Dict(period => i for (i, period) in enumerate(periods))

    # Obtener tecnologías únicas
    unique_techs = names(filtered_df)[2:end]    # Excluir la columna 'period'

    # Crear un diccionario que mapea tecnologías a posiciones enteras para el apilamiento
    tech_position_mapping = Dict(tech => i for (i, tech) in enumerate(unique_techs))

    # Agregar una nueva columna con la posición entera de la tecnología
    filtered_df_long = stack(filtered_df, Not(:period), variable_name = :gen_tech, value_name = :capacity)
    filtered_df_long[:, :tech_position] = [tech_position_mapping[tech] for tech in filtered_df_long.gen_tech]

    # Graficar la gráfica de barras apiladas
    barplot = barplot!(ax,
        [period_mapping[period] for period in filtered_df_long.period],
        filtered_df_long.capacity,
        stack = filtered_df_long.tech_position,
        color = [colors[tech] for tech in filtered_df_long.gen_tech],
        width = 0.5,
        label = [string(tech) for tech in unique_techs])

    # Crear la leyenda con colores correctos
    Legend(fig[1, 2],
        [PolyElement(color = colors[tech]) for tech in unique_techs],
        string.("Tecnología: ", unique_techs);
        labelcolor = :black,
        labelsize = 12,
        titlecolor = :black,
        titlefont = 10)

    # Guardar la figura en la ruta especificada
    save(joinpath(scenario, "Icap_stacked_bar_chart_total.png"), fig)

    # Mostrar la figura
    display(fig)
end

println("Procesamiento completo.")
