using CSV
using DataFrames


# Diccionario para asignar nombres reales a las zonas
catalogo_zonas1 = Dict(
    "Arica y Parinacota" => "Parinacota220",
    "Tarapaca" => "Lagunas220",
    "Tarapaca_2" => "NuevaPozoAlmonte220",
    "Antofagasta" => "Kimal220",
    "Antofagasta_2" => "LosChangos500",
    "Antofagasta_3" => "Parinas500",
    "Antofagasta_4" => "LosChangos220",
    "Antofagasta_5" => "Kimal500",
    "Antofagasta_5H2" => "Kimal500H2",
    "Antofagasta_7" => "NuevaZaldivar220",
    "Los Lagos" => "NuevaPuertoMontt500",
    "Los Lagos_2" => "NuevaAncud500",
    "Atacama" => "NuevaMaitencillo500",
    "Atacama_2" => "Cumbre500",
    "Atacama_3" => "NuevaCardones500",
    "Los Rios" => "Pichirropulli500",
    "Coquimbo" => "NuevaPandeAzucar500",
    "Bio Bio" => "Mulchen500",
    "Bio Bio_2" => "Concepcion500",
    "Bio Bio_3" => "NuevaCharrua500",
    "Bio Bio_3H2" => "NuevaCharrua500H2",
    "Libertador General Bernardo Ohiggins_2" => "Candelaria500",
    "Libertador General Bernardo Ohiggins" => "Rapel500",
    "Metropolitana de Santiago" => "AltoJahuel500",
    "Metropolitana de Santiago_2" => "Polpaico500",
    "Maule" => "Ancoa500",
    "Valparaiso" => "Quillota500",
    "Araucania" => "RioMalleco500",
    "Metropolitana de Santiago_2H2" => "Polpaico500H2"
)

# Leer los archivos CSV
df_transmission_capacity = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/TA/outputs/transmission.csv", DataFrame)
df_transmission_dispatch = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/TA/outputs/DispatchTx.csv", DataFrame)
df_timeseries = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/TA/inputs/timeseries.csv", DataFrame)

# Convertir las columnas PERIOD a tipo string
df_transmission_capacity.PERIOD = string.(df_transmission_capacity.PERIOD)
df_transmission_dispatch.TRANS_TIMEPOINTS_3 = string.(df_transmission_dispatch.TRANS_TIMEPOINTS_3)

# Crear una columna auxiliar para el periodo en df_transmission_dispatch
df_transmission_dispatch.PERIOD = first.(df_transmission_dispatch.TRANS_TIMEPOINTS_3, 4)

# Realizar el left join entre los dataframes
df_merged = leftjoin(df_transmission_dispatch, df_transmission_capacity, on = [:TRANS_TIMEPOINTS_1 => :trans_lz1, :TRANS_TIMEPOINTS_2 => :trans_lz2, :PERIOD => :PERIOD])

# Seleccionar las columnas necesarias
df_result = select(df_merged, Not([:TRANSMISSION_LINE, :trans_dbid, :trans_length_km, :trans_efficiency, :trans_derating_factor, :TxCapacityNameplateAvailable, :TotalAnnualCost]))

# Eliminar filas donde TRANS_TIMEPOINTS_1 o TRANS_TIMEPOINTS_2 contienen el substring "Gxnode-"
df_filtered = filter(row -> !occursin("Gxnode-", row.TRANS_TIMEPOINTS_1) && !occursin("Gxnode-", row.TRANS_TIMEPOINTS_2), df_result)

# Eliminar todas las filas con valores missing en la columna TxCapacityNameplate
df_filtered_no_missing = dropmissing(df_filtered, :TxCapacityNameplate)

# Añadir las columnas Dia y Hora
df_filtered_no_missing.Dia = [row.TRANS_TIMEPOINTS_3[5:6] for row in eachrow(df_filtered_no_missing)]
df_filtered_no_missing.Hora = [row.TRANS_TIMEPOINTS_3[9:10] for row in eachrow(df_filtered_no_missing)]

# Añadir la columna de % de utilización de la línea de transmisión
df_filtered_no_missing.Utilizacion = [row.DispatchTx / row.TxCapacityNameplate * 100 for row in eachrow(df_filtered_no_missing)]

# Agrupar por TRANS_TIMEPOINTS_1, TRANS_TIMEPOINTS_2, PERIOD y Dia, y contar las horas con Utilizacion >= 95
df_grouped = combine(groupby(df_filtered_no_missing, [:TRANS_TIMEPOINTS_1, :TRANS_TIMEPOINTS_2, :PERIOD, :Dia]), 
                     :Utilizacion => (x -> sum(x .>= 95)) => :Horas_Utilizacion_95)

# Añadir la columna ts_scale_to_period
df_grouped.ts_scale_to_period = repeat(df_timeseries.ts_scale_to_period, inner=1, outer=ceil(Int, nrow(df_grouped) / 12))[1:nrow(df_grouped)]
# df_grouped
# Añadir la nueva columna con las condiciones especificadas
df_grouped.Nueva_Columna = [row.Horas_Utilizacion_95 * row.ts_scale_to_period *
    (row.Dia in ["04", "08", "12"] ? 4 : 1) *
    (row.PERIOD == "2024" ? 0.5 : row.PERIOD == "2026" ? 1/3 : row.PERIOD == "2031" ? 0.5 : row.PERIOD == "2033" ? 1/7 : row.PERIOD in ["2040", "2050"] ? 0.1 : 1)
    for row in eachrow(df_grouped)]

CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/TA/Congestions_Temporada_completo.csv", df_grouped)
# Sumar todos los valores de Nueva_Columna para cada combinación de TRANS_TIMEPOINTS_1, TRANS_TIMEPOINTS_2 y PERIOD
df_final = combine(groupby(df_grouped, [:TRANS_TIMEPOINTS_1, :TRANS_TIMEPOINTS_2, :PERIOD]), 
                   :Nueva_Columna => sum => :Horas_Congestionada)

# Cambiar los nombres de las zonas en las columnas TRANS_TIMEPOINTS_1 y TRANS_TIMEPOINTS_2
df_final.TRANS_TIMEPOINTS_1 = [get(catalogo_zonas1, row.TRANS_TIMEPOINTS_1, row.TRANS_TIMEPOINTS_1) for row in eachrow(df_final)]
df_final.TRANS_TIMEPOINTS_2 = [get(catalogo_zonas1, row.TRANS_TIMEPOINTS_2, row.TRANS_TIMEPOINTS_2) for row in eachrow(df_final)]
# Mostrar el dataframe resultante
# println(df_final)

CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/TA/Congestions.csv", df_final)

# Crear una copia del dataframe df_grouped
df_grouped_copia = deepcopy(df_grouped)

# Generar la nueva columna "Estación"
estaciones = ["Verano 1", "Invierno", "Verano 2"]
df_grouped_copia.Estacion = repeat(estaciones, inner=4, outer=ceil(Int, nrow(df_grouped_copia) / 12))[1:nrow(df_grouped_copia)]

# Agrupar y sumar los valores de Nueva_Columna por TRANS_TIMEPOINTS_1, TRANS_TIMEPOINTS_2, PERIOD y Estacion
df_grouped_copia_con_Temporada = combine(groupby(df_grouped_copia, [:TRANS_TIMEPOINTS_1, :TRANS_TIMEPOINTS_2, :PERIOD, :Estacion]), 
                                         :Nueva_Columna => sum => :Horas_Congestionada)

# Cambiar los nombres de las zonas en las columnas TRANS_TIMEPOINTS_1 y TRANS_TIMEPOINTS_2
df_grouped_copia_con_Temporada.TRANS_TIMEPOINTS_1 = [get(catalogo_zonas1, row.TRANS_TIMEPOINTS_1, row.TRANS_TIMEPOINTS_1) for row in eachrow(df_grouped_copia_con_Temporada)]
df_grouped_copia_con_Temporada.TRANS_TIMEPOINTS_2 = [get(catalogo_zonas1, row.TRANS_TIMEPOINTS_2, row.TRANS_TIMEPOINTS_2) for row in eachrow(df_grouped_copia_con_Temporada)]

# Mostrar el dataframe resultante
# println(df_grouped_copia_con_Temporada)

# Escribir el dataframe resultante a un archivo CSV
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/TA/Congestions_Temporada.csv", df_grouped_copia_con_Temporada)

using CSV
using DataFrames

# Función para transformar el dataframe
function transform_dataframe(df::DataFrame)
    # Convertir el DataFrame a un array de arrays
    array_data = Matrix(df)
    
    # Transponer el array
    transposed_array = permutedims(array_data)
    
    # Crear un nuevo DataFrame a partir del array transpuesto
    df_transposed = DataFrame(transposed_array, :auto)
    
    # Renombrar las columnas
    rename!(df_transposed, Symbol.("Col " .* string.(1:ncol(df_transposed))))
    
    # Añadir una nueva primera columna con los nombres originales de las columnas
    insertcols!(df_transposed, 1, :Original_Column => names(df))
    
    return df_transposed
end

# Leer los archivos CSV en dataframes
df_grouped = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/RL/Congestions_Temporada_completo.csv", DataFrame)
df_final = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/RL/Congestions.csv", DataFrame)
df_grouped_copia_con_Temporada = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/RL/Congestions_Temporada.csv", DataFrame)

# Transformar los dataframes
df_grouped_transformed = transform_dataframe(df_grouped)
df_final_transformed = transform_dataframe(df_final)
df_grouped_copia_con_Temporada_transformed = transform_dataframe(df_grouped_copia_con_Temporada)

# Guardar los dataframes transformados en nuevos archivos CSV
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/RL/Congestions_Temporada_completo_transformed.csv", df_grouped_transformed)
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/RL/Congestions_transformed.csv", df_final_transformed)
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/RL/Congestions_Temporada_transformed.csv", df_grouped_copia_con_Temporada_transformed)