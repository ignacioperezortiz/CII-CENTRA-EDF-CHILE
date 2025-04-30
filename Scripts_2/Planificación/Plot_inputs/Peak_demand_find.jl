using CSV
using DataFrames
using Dates
using Plots
using Printf

# Leer el CSV
df = CSV.read("G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_demand/demand.csv", DataFrame)

# Definir los escenarios
escenarios = ["transicion_acelerada", "rumbo_CN", "recuperacion_lenta"]

# Función para calcular la demanda total por año para un escenario
function calcular_demanda_por_escenario(escenario, df)
    # Filtrar los datos por escenario
    df_filtrado = filter(row -> row.scenario == escenario, df)
    
    # Convertir la columna 'time' a DateTime
    df_filtrado[!, :time] .= DateTime.(df_filtrado[!, :time], "yyyy-mm-dd-HH:MM")
    
    # Obtener los nombres de las columnas que contienen las demandas
    nodos = names(df_filtrado)[3:end]
    
    # Crear una nueva columna 'suma_filas' para almacenar la suma de las columnas desde la 3 hasta el final
    df_filtrado[!, :suma_filas] = sum.(eachrow(df_filtrado[:, 3:end]))
    
    # Inicializar un DataFrame para almacenar los máximos por año para este escenario
    df_maximos = DataFrame(year=Int[], max_demand=Float64[])
    
    # Para cada año, calcular la demanda total y encontrar el máximo
    for año in unique(year.(df_filtrado[!, :time]))
        # Filtrar las filas correspondientes a ese año
        df_año = filter(row -> year(row.time) == año, df_filtrado)
        
        # Encontrar el valor máximo de la columna 'suma_filas' cada 288 filas
        n_filas = nrow(df_año)
        maximos = Float64[]
        
        for i in 1:288:n_filas
            # Limitar el rango de filas a cada bloque de 288
            bloque = df_año[i:min(i+287, n_filas), :]
            maximo_bloque = maximum(bloque[:, :suma_filas])  # Obtener el máximo en la columna 'suma_filas'
            push!(maximos, maximo_bloque)
        end
        
        # Si se encontraron máximos, agregarlos al DataFrame
        for maximo in maximos
            push!(df_maximos, (año, maximo))
        end
    end
    
    # Mostrar los máximos encontrados para este escenario
    # println("Máximos por bloque para el escenario $escenario:")
    # println(df_maximos)
    
    # Devolver el DataFrame con los máximos para este escenario
    return df_maximos
end

# Crear un diccionario para almacenar los DataFrames de máximos por cada escenario
maximos_por_escenario = Dict{String, DataFrame}()

# Ejecutar el cálculo para cada escenario y almacenar los resultados
for escenario in escenarios
    df_maximos = calcular_demanda_por_escenario(escenario, df)
    maximos_por_escenario[escenario] = df_maximos
end

# Mostrar los resultados para cada escenario
for escenario in escenarios
    println("\nMaximos para el escenario $escenario:")
    println(maximos_por_escenario[escenario])
end