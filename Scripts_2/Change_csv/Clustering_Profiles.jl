# Sun

# script for clustering sun and wind profiles. the idea is to find a cluster that represents a secuence of 4 days 
# with dry conditions for renewable resources (sun and wind)
# the data we have is for each busbar of the chilean power sistem.
# the data have a hourly resolution. data aviable from 1980 up to 2017, for all days of each year.

# First call the packages.

using Plots, Statistics
using DataFrames, XLSX, Query, Dates
using Clustering
using JuMP, HiGHS
using CSV
using DataFrames
using ExcelFiles
using RegularExpressions
using Colors
# using PlotlyJS
# using CairoMakie
# using GLMakie
# plotlyjs()

nclust = 9
# declare functions

function getData(df2,deltaMin,date1,date2)
    #df2: dataframe with data
    
    df2 = @from i in df2 begin
        @where i.timeStamp >= date1 && i.timeStamp < date2
        @select {i.timeStamp, i.GHI, i.WIND}
        @collect DataFrame
    end

    df2 = dropmissing(df2)
    numDays = Int.(ceil(datetime2julian(date2)-datetime2julian(date1)))

    dataGHI = zeros(24*Int.(60/deltaMin),numDays)
    dataWIND = zeros(24*Int.(60/deltaMin),numDays)

    day_index = 0
    for d in 1:numDays
        actual_date = date1 + Dates.Day(d-1)   # hacer depender de iter
        day_index = day_index + 1
        df_day = @from i in df2 begin
            @where i.timeStamp >= actual_date && i.timeStamp < actual_date + Dates.Day(1)
            @select {i.timeStamp, i.GHI, i.WIND}
            @collect DataFrame
        end
        for i in 1:size(df_day)[1]
            time_index = Int.((Dates.hour(Dates.DateTime(df_day.timeStamp[i]))*60+Dates.minute(Dates.DateTime(df_day.timeStamp[i])))/deltaMin+1)
            dataGHI[time_index,day_index] = df_day.GHI[i]
            dataWIND[time_index,day_index] = df_day.WIND[i]
        end
    end
    return dataGHI, dataWIND
end

function getData2(df2,deltaMin,date1,date2)
    #df2: dataframe with data
    
    df2 = @from i in df2 begin
        @where i.timeStamp >= date1 && i.timeStamp < date2
        @select {i.timeStamp, i.GHI, i.WIND}
        @collect DataFrame
    end

    df2 = dropmissing(df2)
    numDays = Int.(ceil(datetime2julian(date2)-datetime2julian(date1)))

    dataGHI = []
    dataWIND = []

    day_index = 0
    for d in 1:numDays
        actual_date = date1 + Dates.Day(d-1)   # hacer depender de iter
        day_index = day_index + 1
        df_day = @from i in df2 begin
            @where i.timeStamp >= actual_date && i.timeStamp < actual_date + Dates.Day(1)
            @select {i.timeStamp, i.GHI, i.WIND}
            @collect DataFrame
        end
        for i in 1:size(df_day)[1]
            time_index = Int.((Dates.hour(Dates.DateTime(df_day.timeStamp[i]))*60+Dates.minute(Dates.DateTime(df_day.timeStamp[i])))/deltaMin+1)
            push!(dataGHI, df_day.GHI[i])
            push!(dataWIND, df_day.WIND[i])
        end
    end
    return dataGHI, dataWIND
end

function cleanData(data::DataFrame)
    # Filtrar las filas que no contienen la cadena "NaN" en ninguna de las columnas
    return filter!(row -> !isnan(row.GHI), data)
end

# Acá obtengo las irradianzas y temperaturas...
df_IRR = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Sun/Antofagasta.csv", DataFrame)
ncol(df_IRR)
rename!(df_IRR,[:Date,:GLB,:DIR,:DIF,:SCT,:GHI,:DIRH,:DIFH,:DNI,:TAMB,:WIND,:SHADOW,:CLOUD])
# Crear la columna timeStamp con ceros
df_IRR.timeStamp = fill(DateTime(0), nrow(df_IRR))

# Recorrer el DataFrame y asignar DateTime a cada elemento de la columna timeStamp
for i in 1:nrow(df_IRR)
    df_IRR.timeStamp[i] = DateTime(parse(Int, df_IRR.Date[i][1:4]), parse(Int, df_IRR.Date[i][6:7]), parse(Int, df_IRR.Date[i][9:10]), parse(Int, df_IRR.Date[i][12:13]))
end

df = df_IRR[!, [:timeStamp, :GHI, :WIND]]
df = cleanData(df)

# años
years1 = []
for i in df.timeStamp
    push!(years1, year(i))
end
years = unique(years1)
println(years)

# years = [2004,2005,2006,2007,2008]
temporadas = ["Verano1"]

dict_temporadas = Dict("Verano1"=> 1)

promedio_viento_por_temporada = []
for j in temporadas
    season = dict_temporadas[j]
    for i in years
        if j == "Verano1"
            deltaMin = 60
            time = deltaMin*[1:24]/60
            date_1 = DateTime(i,1,1,0)
            date_2 = DateTime(i,4,30,23)
            Data_Irr_GHI1, Data_Irr_WIND1 = getData2(df,deltaMin,date_1,date_2)
            WIND = Data_Irr_WIND1
            SUN = Data_Irr_GHI1
            promedio_WIND = mean(WIND)
            promedio_SUN = mean(SUN)
            push!(promedio_viento_por_temporada, (j, promedio_WIND, promedio_SUN))
        end
    end
end
df_promedios = DataFrame(promedio_viento_por_temporada, [:Temporada, :Promedio_WIND, :Promedio_SUN])

cuatro_dias_list = []
for j in temporadas
    season = dict_temporadas[j]
    for i in years
        if j == "Verano1"
            deltaMin = 60
            time = deltaMin*[1:24]/60
            date_1 = DateTime(i,1,1,0)
            date_2 = DateTime(i,4,30,23)
            numDays = Int.(ceil(datetime2julian(date_2)-datetime2julian(date_1)))
            for m in 1:numDays-3
            # for m in 1:1
                date1 = date_1 + Dates.Day(m-1)
                date2 = date1 + Dates.Day(4)
                Data_Irr_GHI, Data_Irr_WIND = getData(df,deltaMin,date1,date2)
                
                # perfiles sol y viento 4 dias seguidos
                GHI1 = Data_Irr_GHI[:,1]
                GHI2 = Data_Irr_GHI[:,2]
                GHI3 = Data_Irr_GHI[:,3]
                GHI4 = Data_Irr_GHI[:,4]
                WIND1 = Data_Irr_WIND[:,1]
                WIND2 = Data_Irr_WIND[:,2]
                WIND3 = Data_Irr_WIND[:,3]
                WIND4 = Data_Irr_WIND[:,4]

                # generar estadisticos para esta serie de 4 dias
                # viento 
                # velocidad_max_viento1 = maximum([maximum(WIND1), maximum(WIND2)])
                # velocidad_max_viento2 = maximum([maximum(WIND3), maximum(WIND4)])
                # velocidad_max_viento_dif = abs(velocidad_max_viento1-velocidad_max_viento2)
                # velocidad_min_viento1 = minimum([minimum(WIND1), minimum(WIND2)])
                # velocidad_min_viento2 = minimum([minimum(WIND3), minimum(WIND4)])
                # velocidad_min_viento_dif = abs(velocidad_min_viento1-velocidad_min_viento2)
                velocidad_prom_viento1 = mean([mean(WIND1), mean(WIND2)])
                velocidad_prom_viento2 = mean([mean(WIND3), mean(WIND4)])
                velocidad_prom_viento_dif = abs(velocidad_prom_viento1-velocidad_prom_viento2)
                velocidad_prom_viento_max = maximum([velocidad_prom_viento1,velocidad_prom_viento2])
                potencia_prom_solar1 = mean([mean(GHI1), mean(GHI2)])
                potencia_prom_solar2 = mean([mean(GHI3), mean(GHI4)])
                potencia_prom_solar_dif = abs(potencia_prom_solar1-potencia_prom_solar2)
                potencia_prom_solar_max = maximum([potencia_prom_solar1,potencia_prom_solar2])
                if potencia_prom_solar_max > df_promedios.Promedio_SUN[1] && potencia_prom_solar_max - potencia_prom_solar_dif < df_promedios.Promedio_SUN[1]
                    Hay_sequia_SUN = 1
                else
                    Hay_sequia_SUN = 0
                end
                # energia_viento1 = sum([sum(WIND1), sum(WIND2)])
                # energia_viento2 = sum([sum(WIND3), sum(WIND4)])
                # energia_viento_dif = abs(energia_viento1-energia_viento2)
                # if velocidad_max_viento1 > 0
                #     factor_planta_viento1 = energia_viento1/(velocidad_max_viento1*48) 
                # else
                #     factor_planta_viento1 = 0
                # end
                # if velocidad_max_viento2 > 0
                #     factor_planta_viento2 = energia_viento2/(velocidad_max_viento1*48) 
                # else
                #     factor_planta_viento2 = 0
                # end
                # factor_planta_viento_dif = abs(factor_planta_viento1-factor_planta_viento2)
                push!(cuatro_dias_list, (i, j, m, date1, potencia_prom_solar_max, potencia_prom_solar_dif, Hay_sequia_SUN))
                # push!(cuatro_dias_list, (velocidad_max_viento1,velocidad_max_viento2,velocidad_min_viento1,velocidad_min_viento2,velocidad_prom_viento1,velocidad_prom_viento2,energia_viento1,energia_viento2,factor_planta_viento1,factor_planta_viento2))
            end
        end
    end
end

df_pre_cluster = DataFrame(cuatro_dias_list, [:Año, :Temporada, :Dia, :fecha, :potencia_prom_solar_max, :potencia_prom_solar_dif, :Hay_sequia_SUN])
# println(df_pre_cluster)

# Aplicar K-Means Clustering
df_pre_cluster_copy = df_pre_cluster[!, [:potencia_prom_solar_max, :potencia_prom_solar_dif, :Hay_sequia_SUN]]
matrix_pre_cluster = Matrix(df_pre_cluster_copy)'
Result = kmeans(matrix_pre_cluster, nclust, maxiter=2000, display=:none)  # Puedes cambiar el número de clusters según lo necesites
Centroides = Result.centers
Asignaciones = Result.assignments
Conteo = Result.counts
df_post_cluster = df_pre_cluster
df_post_cluster.Cluster = Asignaciones
println(df_post_cluster)
println(Centroides)
println(Conteo)

# plotting

color_palette = [
    RGB(0.1, 0.2, 0.5), 
    RGB(0.9, 0.2, 0.2), 
    RGB(0.2, 0.7, 0.2), 
    RGB(0.9, 0.7, 0.0), 
    RGB(0.8, 0.5, 0.8), 
    RGB(0.5, 0.5, 0.9), 
    RGB(0.7, 0.7, 0.1), 
    RGB(0.6, 0.3, 0.1),
    RGB(0.1, 0.9, 0.8),
    RGB(0.3, 0.6, 0.1),  # Nuevo color verde más brillante
    RGB(0.9, 0.5, 0.8)   # Nuevo color rosa suave
]


# todos los centroides
# Crear el primer gráfico vacío, solo si no se ha creado antes
scatter(df_post_cluster.potencia_prom_solar_max, df_post_cluster.potencia_prom_solar_dif,
        xlabel="Velocidad Promedio Maxima (m/s)", 
        ylabel="Diferencia de Velocidad Promedio (m/s)",
        zlabel ="Hay sequia o no",
        title="Clustering K-Means: Velocidad del Viento",  
        titlesize=12,   # Reducir el tamaño del título del gráfico
        legend=:topleft,  # Colocar la leyenda en la parte superior derecha
        label=nothing)  # No añadir etiquetas automáticas

# Graficar los puntos de cada cluster
for i in 1:nclust
    df_for_cluster = filter(row -> row.Cluster == i, df_post_cluster)
    scatter!(df_for_cluster.potencia_prom_solar_max, df_for_cluster.potencia_prom_solar_dif,
             color=color_palette[i],  # Asignamos el color correspondiente a cada cluster
             label="Cluster$i")  # Añadir la leyenda de cada cluster
end

# Graficar los centroides en color negro
scatter!(Centroides[1,:], Centroides[2,:],
         color=:black,  # Los centroides en negro
         marker=:star, 
         label="Centroides", 
         markersize=8)








# 1 con sequia
df_With_Sequia = filter(row->row.Hay_sequia_SUN == 1, df_post_cluster)
# Crear el primer gráfico vacío, solo si no se ha creado antes
scatter(df_With_Sequia.potencia_prom_solar_max, df_With_Sequia.potencia_prom_solar_dif,
        xlabel="Velocidad Promedio Maxima (m/s)", 
        ylabel="Diferencia de Velocidad Promedio (m/s)",
        zlabel ="Hay sequia o no",
        title="Clustering K-Means: Velocidad del Viento",  
        titlesize=12,   # Reducir el tamaño del título del gráfico
        legend=:topleft,  # Colocar la leyenda en la parte superior derecha
        label=nothing)  # No añadir etiquetas automáticas

# Graficar los puntos de cada cluster
for i in 1:nclust
    df_for_cluster = filter(row -> row.Cluster == i, df_With_Sequia)
    scatter!(df_for_cluster.potencia_prom_solar_max, df_for_cluster.potencia_prom_solar_dif,
             color=color_palette[i],  # Asignamos el color correspondiente a cada cluster
             label="Cluster$i")  # Añadir la leyenda de cada cluster
end

# Graficar los centroides en color negro
scatter!(Centroides[1,:], Centroides[2,:],
         color=:black,  # Los centroides en negro
         marker=:star, 
         label="Centroides", 
         markersize=8)







# sin sequia
df_Without_Sequia = filter(row->row.Hay_sequia_SUN == 0, df_post_cluster)
# Crear el primer gráfico vacío, solo si no se ha creado antes
scatter(df_Without_Sequia.potencia_prom_solar_max, df_Without_Sequia.potencia_prom_solar_dif,
        xlabel="Velocidad Promedio Maxima (m/s)", 
        ylabel="Diferencia de Velocidad Promedio (m/s)",
        zlabel ="Hay sequia o no",
        title="Clustering K-Means: Velocidad del Viento",  
        titlesize=12,   # Reducir el tamaño del título del gráfico
        legend=:topleft,  # Colocar la leyenda en la parte superior derecha
        label=nothing)  # No añadir etiquetas automáticas

# Graficar los puntos de cada cluster
for i in 1:nclust
    df_for_cluster = filter(row -> row.Cluster == i, df_Without_Sequia)
    scatter!(df_for_cluster.potencia_prom_solar_max, df_for_cluster.potencia_prom_solar_dif,
             color=color_palette[i],  # Asignamos el color correspondiente a cada cluster
             label="Cluster$i")  # Añadir la leyenda de cada cluster
end

# Graficar los centroides en color negro
scatter!(Centroides[1,:], Centroides[2,:],
         color=:black,  # Los centroides en negro
         marker=:star, 
         label="Centroides", 
         markersize=8)



# Histograma 
# Definir los nombres de los clusters
cluster_names = ["Cluster 1", "Cluster 2", "Cluster 3", "Cluster 4", 
                 "Cluster 5", "Cluster 6", "Cluster 7", "Cluster 8","Cluster 9","Cluster 10", "Cluster 11"]

# Contamos la cantidad de puntos por cluster
cluster_counts = [sum(df_post_cluster.Cluster .== i) for i in 1:nclust]

# Crear el histograma de barras con nombres personalizados para los ticks del eje X
bar(1:nclust, cluster_counts, 
    xlabel="Cluster", 
    ylabel="Número de Puntos", 
    title="Distribución de Puntos por Cluster", 
    color=color_palette,  # Usamos la paleta de colores
    legend=:none,  # No mostrar leyenda
    width=0.5,  # Ancho de las barras
    grid=true,  # Cuadrícula
    xticks=(1:nclust, cluster_names))
    # yticks=cluster_counts)  # Cambiar los ticks del eje X por los nombres de los clusters




# histograma de probabilidad
# Definir los nombres de los clusters
cluster_names = ["Cluster 1", "Cluster 2", "Cluster 3", "Cluster 4", 
                 "Cluster 5", "Cluster 6", "Cluster 7", "Cluster 8","Cluster 9","Cluster 10", "Cluster 11"]

# Contamos la cantidad de puntos por cluster
cluster_counts = [sum(df_post_cluster.Cluster .== i) for i in 1:nclust]

# Total de puntos en el DataFrame
total_points = length(df_post_cluster.Cluster)

# Calcular las probabilidades para cada cluster
cluster_probabilities = cluster_counts ./ total_points  # Dividimos por el total de puntos

# Crear el histograma de probabilidades con nombres personalizados para los ticks del eje X
bar(1:nclust, cluster_probabilities, 
    xlabel="Cluster", 
    ylabel="Probabilidad", 
    title="Distribución de Probabilidades por Cluster", 
    color=color_palette,  # Usamos la paleta de colores
    legend=:none,  # No mostrar leyenda
    width=0.5,  # Ancho de las barras
    grid=true,  # Cuadrícula
    xticks=(1:nclust, cluster_names))
    # yticks=cluster_probabilities)  # Cambiar los ticks del eje X por los nombres de los clusters










# wind 

# script for clustering sun and wind profiles. the idea is to find a cluster that represents a secuence of 4 days 
# with dry conditions for renewable resources (sun and wind)
# the data we have is for each busbar of the chilean power sistem.
# the data have a hourly resolution. data aviable from 1980 up to 2017, for all days of each year.

# First call the packages.

using Plots, Statistics
using DataFrames, XLSX, Query, Dates
using Clustering
using JuMP, HiGHS
using CSV
using DataFrames
using ExcelFiles
using RegularExpressions
using Colors
# using PlotlyJS
# using CairoMakie
# using GLMakie
# plotlyjs()

nclust = 9
# declare functions

function getData(df2,deltaMin,date1,date2)
    #df2: dataframe with data
    
    df2 = @from i in df2 begin
        @where i.timeStamp >= date1 && i.timeStamp < date2
        @select {i.timeStamp, i.GHI, i.WIND}
        @collect DataFrame
    end

    df2 = dropmissing(df2)
    numDays = Int.(ceil(datetime2julian(date2)-datetime2julian(date1)))

    dataGHI = zeros(24*Int.(60/deltaMin),numDays)
    dataWIND = zeros(24*Int.(60/deltaMin),numDays)

    day_index = 0
    for d in 1:numDays
        actual_date = date1 + Dates.Day(d-1)   # hacer depender de iter
        day_index = day_index + 1
        df_day = @from i in df2 begin
            @where i.timeStamp >= actual_date && i.timeStamp < actual_date + Dates.Day(1)
            @select {i.timeStamp, i.GHI, i.WIND}
            @collect DataFrame
        end
        for i in 1:size(df_day)[1]
            time_index = Int.((Dates.hour(Dates.DateTime(df_day.timeStamp[i]))*60+Dates.minute(Dates.DateTime(df_day.timeStamp[i])))/deltaMin+1)
            dataGHI[time_index,day_index] = df_day.GHI[i]
            dataWIND[time_index,day_index] = df_day.WIND[i]
        end
    end
    return dataGHI, dataWIND
end

function getData2(df2,deltaMin,date1,date2)
    #df2: dataframe with data
    
    df2 = @from i in df2 begin
        @where i.timeStamp >= date1 && i.timeStamp < date2
        @select {i.timeStamp, i.GHI, i.WIND}
        @collect DataFrame
    end

    df2 = dropmissing(df2)
    numDays = Int.(ceil(datetime2julian(date2)-datetime2julian(date1)))

    dataGHI = []
    dataWIND = []

    day_index = 0
    for d in 1:numDays
        actual_date = date1 + Dates.Day(d-1)   # hacer depender de iter
        day_index = day_index + 1
        df_day = @from i in df2 begin
            @where i.timeStamp >= actual_date && i.timeStamp < actual_date + Dates.Day(1)
            @select {i.timeStamp, i.GHI, i.WIND}
            @collect DataFrame
        end
        for i in 1:size(df_day)[1]
            time_index = Int.((Dates.hour(Dates.DateTime(df_day.timeStamp[i]))*60+Dates.minute(Dates.DateTime(df_day.timeStamp[i])))/deltaMin+1)
            push!(dataGHI, df_day.GHI[i])
            push!(dataWIND, df_day.WIND[i])
        end
    end
    return dataGHI, dataWIND
end

function cleanData(data::DataFrame)
    # Filtrar las filas que no contienen la cadena "NaN" en ninguna de las columnas
    return filter!(row -> !isnan(row.GHI), data)
end

# Acá obtengo las irradianzas y temperaturas...
df_IRR = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Sun/Antofagasta.csv", DataFrame)
ncol(df_IRR)
rename!(df_IRR,[:Date,:GLB,:DIR,:DIF,:SCT,:GHI,:DIRH,:DIFH,:DNI,:TAMB,:WIND,:SHADOW,:CLOUD])
# Crear la columna timeStamp con ceros
df_IRR.timeStamp = fill(DateTime(0), nrow(df_IRR))

# Recorrer el DataFrame y asignar DateTime a cada elemento de la columna timeStamp
for i in 1:nrow(df_IRR)
    df_IRR.timeStamp[i] = DateTime(parse(Int, df_IRR.Date[i][1:4]), parse(Int, df_IRR.Date[i][6:7]), parse(Int, df_IRR.Date[i][9:10]), parse(Int, df_IRR.Date[i][12:13]))
end

df = df_IRR[!, [:timeStamp, :GHI, :WIND]]
df = cleanData(df)

# años
years1 = []
for i in df.timeStamp
    push!(years1, year(i))
end
years = unique(years1)
println(years)

# years = [2004,2005,2006,2007,2008]
temporadas = ["Verano1"]

dict_temporadas = Dict("Verano1"=> 1)

promedio_viento_por_temporada = []
for j in temporadas
    season = dict_temporadas[j]
    for i in years
        if j == "Verano1"
            deltaMin = 60
            time = deltaMin*[1:24]/60
            date_1 = DateTime(i,1,1,0)
            date_2 = DateTime(i,4,30,23)
            Data_Irr_GHI1, Data_Irr_WIND1 = getData2(df,deltaMin,date_1,date_2)
            WIND = Data_Irr_WIND1
            SUN = Data_Irr_GHI1
            promedio_WIND = mean(WIND)
            promedio_SUN = mean(SUN)
            push!(promedio_viento_por_temporada, (j, promedio_WIND, promedio_SUN))
        end
    end
end
df_promedios = DataFrame(promedio_viento_por_temporada, [:Temporada, :Promedio_WIND, :Promedio_SUN])

cuatro_dias_list = []
for j in temporadas
    season = dict_temporadas[j]
    for i in years
        if j == "Verano1"
            deltaMin = 60
            time = deltaMin*[1:24]/60
            date_1 = DateTime(i,1,1,0)
            date_2 = DateTime(i,4,30,23)
            numDays = Int.(ceil(datetime2julian(date_2)-datetime2julian(date_1)))
            for m in 1:numDays-3
            # for m in 1:1
                date1 = date_1 + Dates.Day(m-1)
                date2 = date1 + Dates.Day(4)
                Data_Irr_GHI, Data_Irr_WIND = getData(df,deltaMin,date1,date2)
                
                # perfiles sol y viento 4 dias seguidos
                GHI1 = Data_Irr_GHI[:,1]
                GHI2 = Data_Irr_GHI[:,2]
                GHI3 = Data_Irr_GHI[:,3]
                GHI4 = Data_Irr_GHI[:,4]
                WIND1 = Data_Irr_WIND[:,1]
                WIND2 = Data_Irr_WIND[:,2]
                WIND3 = Data_Irr_WIND[:,3]
                WIND4 = Data_Irr_WIND[:,4]

                # generar estadisticos para esta serie de 4 dias
                # viento 
                # velocidad_max_viento1 = maximum([maximum(WIND1), maximum(WIND2)])
                # velocidad_max_viento2 = maximum([maximum(WIND3), maximum(WIND4)])
                # velocidad_max_viento_dif = abs(velocidad_max_viento1-velocidad_max_viento2)
                # velocidad_min_viento1 = minimum([minimum(WIND1), minimum(WIND2)])
                # velocidad_min_viento2 = minimum([minimum(WIND3), minimum(WIND4)])
                # velocidad_min_viento_dif = abs(velocidad_min_viento1-velocidad_min_viento2)
                velocidad_prom_viento1 = mean([mean(WIND1), mean(WIND2)])
                velocidad_prom_viento2 = mean([mean(WIND3), mean(WIND4)])
                velocidad_prom_viento_dif = abs(velocidad_prom_viento1-velocidad_prom_viento2)
                velocidad_prom_viento_max = maximum([velocidad_prom_viento1,velocidad_prom_viento2])
                velocidad_prom_viento_min = minimum([velocidad_prom_viento1,velocidad_prom_viento2])
                potencia_prom_solar1 = mean([mean(GHI1), mean(GHI2)])
                potencia_prom_solar2 = mean([mean(GHI3), mean(GHI4)])
                potencia_prom_solar_dif = abs(potencia_prom_solar1-potencia_prom_solar2)
                if velocidad_prom_viento_max > df_promedios.Promedio_WIND[1] && velocidad_prom_viento_max - velocidad_prom_viento_dif < df_promedios.Promedio_WIND[1]
                    Hay_sequia_WIND = 1
                else
                    Hay_sequia_WIND = 0
                end
                dif_with_prom_WIND = df_promedios.Promedio_WIND[1]-velocidad_prom_viento_min
                # energia_viento1 = sum([sum(WIND1), sum(WIND2)])
                # energia_viento2 = sum([sum(WIND3), sum(WIND4)])
                # energia_viento_dif = abs(energia_viento1-energia_viento2)
                # if velocidad_max_viento1 > 0
                #     factor_planta_viento1 = energia_viento1/(velocidad_max_viento1*48) 
                # else
                #     factor_planta_viento1 = 0
                # end
                # if velocidad_max_viento2 > 0
                #     factor_planta_viento2 = energia_viento2/(velocidad_max_viento1*48) 
                # else
                #     factor_planta_viento2 = 0
                # end
                # factor_planta_viento_dif = abs(factor_planta_viento1-factor_planta_viento2)
                push!(cuatro_dias_list, (i, j, m, date1, velocidad_prom_viento_max, velocidad_prom_viento_min, velocidad_prom_viento_dif, dif_with_prom_WIND, Hay_sequia_WIND,))
                # push!(cuatro_dias_list, (velocidad_max_viento1,velocidad_max_viento2,velocidad_min_viento1,velocidad_min_viento2,velocidad_prom_viento1,velocidad_prom_viento2,energia_viento1,energia_viento2,factor_planta_viento1,factor_planta_viento2))
            end
        end
    end
end

df_pre_cluster = DataFrame(cuatro_dias_list, [:Año, :Temporada, :Dia, :fecha, :velocidad_prom_viento_max,:velocidad_prom_viento_min :velocidad_prom_viento_dif, :dif_with_prom_WIND, :Hay_sequia_WIND])
# println(df_pre_cluster)

# Aplicar K-Means Clustering
df_pre_cluster_copy = df_pre_cluster[!, [:velocidad_prom_viento_max, :velocidad_prom_viento_min, :Hay_sequia_WIND]]
matrix_pre_cluster = Matrix(df_pre_cluster_copy)'
Result = kmeans(matrix_pre_cluster, nclust, maxiter=2000, display=:none)  # Puedes cambiar el número de clusters según lo necesites
Centroides = Result.centers
Asignaciones = Result.assignments
Conteo = Result.counts
df_post_cluster = df_pre_cluster
df_post_cluster.Cluster = Asignaciones
println(df_post_cluster)
println(Centroides)
println(Conteo)

# plotting

color_palette = [
    RGB(0.1, 0.2, 0.5), 
    RGB(0.9, 0.2, 0.2), 
    RGB(0.2, 0.7, 0.2), 
    RGB(0.9, 0.7, 0.0), 
    RGB(0.8, 0.5, 0.8), 
    RGB(0.5, 0.5, 0.9), 
    RGB(0.7, 0.7, 0.1), 
    RGB(0.6, 0.3, 0.1),
    RGB(0.1, 0.9, 0.8)
]# Colores personalizados


# todos los centroides
# Crear el primer gráfico vacío, solo si no se ha creado antes
scatter(df_post_cluster.velocidad_prom_viento_max, df_post_cluster.velocidad_prom_viento_min,
        xlabel="Velocidad Promedio Maxima (m/s)", 
        ylabel="Velocidad Promedio Minimia (m/s)",
        zlabel ="Hay sequia o no",
        title="Clustering K-Means: Velocidad del Viento",  
        titlesize=12,   # Reducir el tamaño del título del gráfico
        legend=:topleft,  # Colocar la leyenda en la parte superior derecha
        label=nothing)  # No añadir etiquetas automáticas

# Graficar los puntos de cada cluster
for i in 1:nclust
    df_for_cluster = filter(row -> row.Cluster == i, df_post_cluster)
    scatter!(df_for_cluster.velocidad_prom_viento_max, df_for_cluster.velocidad_prom_viento_min,
             color=color_palette[i],  # Asignamos el color correspondiente a cada cluster
             label="Cluster$i")  # Añadir la leyenda de cada cluster
end

# Graficar los centroides en color negro
scatter!(Centroides[1,:], Centroides[2,:],
         color=:black,  # Los centroides en negro
         marker=:star, 
         label="Centroides", 
         markersize=8)








# 1 con sequia
df_With_Sequia = filter(row->row.Hay_sequia_WIND == 1, df_post_cluster)
# Crear el primer gráfico vacío, solo si no se ha creado antes
scatter(df_With_Sequia.velocidad_prom_viento_max, df_With_Sequia.velocidad_prom_viento_min,
        xlabel="Velocidad Promedio Maxima (m/s)", 
        ylabel="Velocidad Promedio Minima (m/s)",
        zlabel ="Hay sequia o no",
        title="Clustering K-Means: Velocidad del Viento",  
        titlesize=12,   # Reducir el tamaño del título del gráfico
        legend=:topleft,  # Colocar la leyenda en la parte superior derecha
        label=nothing)  # No añadir etiquetas automáticas

# Graficar los puntos de cada cluster
for i in 1:nclust
    df_for_cluster = filter(row -> row.Cluster == i, df_With_Sequia)
    scatter!(df_for_cluster.velocidad_prom_viento_max, df_for_cluster.velocidad_prom_viento_min,
             color=color_palette[i],  # Asignamos el color correspondiente a cada cluster
             label="Cluster$i")  # Añadir la leyenda de cada cluster
end

# Graficar los centroides en color negro
scatter!(Centroides[1,:], Centroides[2,:],
         color=:black,  # Los centroides en negro
         marker=:star, 
         label="Centroides", 
         markersize=8)







# sin sequia
df_Without_Sequia = filter(row->row.Hay_sequia_WIND == 0, df_post_cluster)
# Crear el primer gráfico vacío, solo si no se ha creado antes
scatter(df_Without_Sequia.velocidad_prom_viento_max, df_Without_Sequia.velocidad_prom_viento_min,
        xlabel="Velocidad Promedio Maxima (m/s)", 
        ylabel="Velocidad Promedio Minima (m/s)",
        zlabel ="Hay sequia o no",
        title="Clustering K-Means: Velocidad del Viento",  
        titlesize=12,   # Reducir el tamaño del título del gráfico
        legend=:topleft,  # Colocar la leyenda en la parte superior derecha
        label=nothing)  # No añadir etiquetas automáticas

# Graficar los puntos de cada cluster
for i in 1:nclust
    df_for_cluster = filter(row -> row.Cluster == i, df_Without_Sequia)
    scatter!(df_for_cluster.velocidad_prom_viento_max, df_for_cluster.velocidad_prom_viento_min,
             color=color_palette[i],  # Asignamos el color correspondiente a cada cluster
             label="Cluster$i")  # Añadir la leyenda de cada cluster
end

# Graficar los centroides en color negro
scatter!(Centroides[1,:], Centroides[2,:],
         color=:black,  # Los centroides en negro
         marker=:star, 
         label="Centroides", 
         markersize=8)



# Histograma 
# Definir los nombres de los clusters
cluster_names = ["Cluster 1", "Cluster 2", "Cluster 3", "Cluster 4", 
                 "Cluster 5", "Cluster 6", "Cluster 7", "Cluster 8","Cluster 9"]

# Contamos la cantidad de puntos por cluster
cluster_counts = [sum(df_post_cluster.Cluster .== i) for i in 1:nclust]

# Crear el histograma de barras con nombres personalizados para los ticks del eje X
bar(1:nclust, cluster_counts, 
    xlabel="Cluster", 
    ylabel="Número de Puntos", 
    title="Distribución de Puntos por Cluster", 
    color=color_palette,  # Usamos la paleta de colores
    legend=:none,  # No mostrar leyenda
    width=0.5,  # Ancho de las barras
    grid=true,  # Cuadrícula
    xticks=(1:nclust, cluster_names))
    # yticks=cluster_counts)  # Cambiar los ticks del eje X por los nombres de los clusters




# histograma de probabilidad
# Definir los nombres de los clusters
cluster_names = ["Cluster 1", "Cluster 2", "Cluster 3", "Cluster 4", 
                 "Cluster 5", "Cluster 6", "Cluster 7", "Cluster 8", "Cluster 9"]

# Contamos la cantidad de puntos por cluster
cluster_counts = [sum(df_post_cluster.Cluster .== i) for i in 1:nclust]

# Total de puntos en el DataFrame
total_points = length(df_post_cluster.Cluster)

# Calcular las probabilidades para cada cluster
cluster_probabilities = cluster_counts ./ total_points  # Dividimos por el total de puntos

# Crear el histograma de probabilidades con nombres personalizados para los ticks del eje X
bar(1:nclust, cluster_probabilities, 
    xlabel="Cluster", 
    ylabel="Probabilidad", 
    title="Distribución de Probabilidades por Cluster", 
    color=color_palette,  # Usamos la paleta de colores
    legend=:none,  # No mostrar leyenda
    width=0.5,  # Ancho de las barras
    grid=true,  # Cuadrícula
    xticks=(1:nclust, cluster_names))
    # yticks=cluster_probabilities)  # Cambiar los ticks del eje X por los nombres de los clusters








# continuamos, ahora vamos a hacer una clusterización de los perfiles de cuatro dias seguidos, pero unicamente los que generan sequia.
nclust2 = 3
df_With_Sequia = filter(row->row.Hay_sequia_WIND == 1, df_post_cluster)
df_pre_cluster2 = df_With_Sequia
df_pre_cluster2_copy = df_pre_cluster2[!, [:dif_with_prom_WIND,:Hay_sequia_WIND]]
matrix_pre_cluster2 = Matrix(df_pre_cluster2_copy)'
Result = kmeans(matrix_pre_cluster2, nclust2, maxiter=2000, display=:none)  # Puedes cambiar el número de clusters según lo necesites
Centroides = Result.centers
Asignaciones = Result.assignments
Conteo = Result.counts
df_post_cluster2 = df_pre_cluster2
df_post_cluster2.Cluster2 = Asignaciones
println(df_post_cluster2)
println(Centroides)
println(Conteo)

# plotting

color_palette = [
    RGB(0.1, 0.2, 0.5), 
    RGB(0.9, 0.2, 0.2), 
    RGB(0.2, 0.7, 0.2), 
    RGB(0.9, 0.7, 0.0), 
    RGB(0.8, 0.5, 0.8), 
    RGB(0.5, 0.5, 0.9), 
    RGB(0.7, 0.7, 0.1), 
    RGB(0.6, 0.3, 0.1),
    RGB(0.1, 0.9, 0.8)
]# Colores personalizados


# todos los centroides
# Crear el primer gráfico vacío, solo si no se ha creado antes
scatter(df_post_cluster2.velocidad_prom_viento_max, df_post_cluster2.velocidad_prom_viento_min,
        xlabel="Velocidad Promedio Maxima (m/s)", 
        ylabel="Velocidad Promedio Minima (m/s)",
        zlabel ="Hay sequia o no",
        title="Clustering K-Means: Velocidad del Viento",  
        titlesize=12,   # Reducir el tamaño del título del gráfico
        legend=:bottomright,  # Colocar la leyenda en la parte superior derecha
        label=nothing)  # No añadir etiquetas automáticas

# Graficar los puntos de cada cluster
for i in 1:nclust2
    df_for_cluster = filter(row -> row.Cluster2 == i, df_post_cluster2)
    scatter!(df_for_cluster.velocidad_prom_viento_max, df_for_cluster.velocidad_prom_viento_min,
             color=color_palette[i],  # Asignamos el color correspondiente a cada cluster
             label="Cluster$i")  # Añadir la leyenda de cada cluster
end

scatter!()
# Graficar los centroides en color negro
scatter!(Centroides[1,:],
         color=:black,  # Los centroides en negro
         marker=:star, 
         label="Centroides", 
         markersize=8)



scatter(df_post_cluster2.dif_with_prom_WIND, df_post_cluster2.Hay_sequia_WIND,
xlabel="Dif entre velocidad promedio minima y promedio temporada", 
ylabel="1 booleano, hay sequia",
title="Clustering K-Means: Velocidad del Viento",  
titlesize=12,   # Reducir el tamaño del título del gráfico
legend=:topleft,  # Colocar la leyenda en la parte superior derecha
yticks=[0,1.0,2.0],
ylims=[0,2],
label=nothing)  # No añadir etiquetas automáticas

# Graficar los puntos de cada cluster
for i in 1:nclust2
df_for_cluster = filter(row -> row.Cluster2 == i, df_post_cluster2)
scatter!(df_for_cluster.dif_with_prom_WIND, df_for_cluster.Hay_sequia_WIND,
    color=color_palette[i],  # Asignamos el color correspondiente a cada cluster
    label="Cluster$i")  # Añadir la leyenda de cada cluster
end

scatter!()
# Graficar los centroides en color negr



cantidad = filter(row -> row.Año == 2004, df_post_cluster2)
println(length(cantidad.Año))
# graficar un perfil en particular
cluster = 2
dframe = filter(row->row.Cluster2 == cluster, df_post_cluster2)
println(dframe)
deltaMin = 60
date_1 = dframe.fecha[11]
date1 = date_1
date2 = date1 + Dates.Day(4)
Data_Irr_GHI, Data_Irr_WIND = getData(df,deltaMin,date1,date2)

# perfiles sol y viento 4 dias seguidos
GHI1 = Data_Irr_GHI[:,1]
GHI2 = Data_Irr_GHI[:,2]
GHI3 = Data_Irr_GHI[:,3]
GHI4 = Data_Irr_GHI[:,4]
vect_tot=vcat(GHI1, GHI2, GHI3, GHI4)
WIND1 = Data_Irr_WIND[:,1]
WIND2 = Data_Irr_WIND[:,2]
WIND3 = Data_Irr_WIND[:,3]
WIND4 = Data_Irr_WIND[:,4]
vect_tot2=vcat(WIND1, WIND2, WIND3, WIND4)
velocidad_prom_viento1 = mean([mean(WIND1), mean(WIND2)])
velocidad_prom_viento2 = mean([mean(WIND3), mean(WIND4)])
velocidad_prom_viento_dif = abs(velocidad_prom_viento1-velocidad_prom_viento2)
velocidad_prom_viento_max = maximum([velocidad_prom_viento1,velocidad_prom_viento2])
velocidad_prom_viento_min = minimum([velocidad_prom_viento1,velocidad_prom_viento2])
potencia_prom_solar1 = mean([mean(GHI1), mean(GHI2)])
potencia_prom_solar2 = mean([mean(GHI3), mean(GHI4)])
potencia_prom_solar_dif = abs(potencia_prom_solar1-potencia_prom_solar2)
plot(vect_tot2)
hline!([2.946], label="Promedio historico")
hline!([velocidad_prom_viento_max], label="Promedio maximo")
hline!([velocidad_prom_viento_min], label="Promedio minimo")





         
# wind + sun promedios

# script for clustering sun and wind profiles. the idea is to find a cluster that represents a secuence of 4 days 
# with dry conditions for renewable resources (sun and wind)
# the data we have is for each busbar of the chilean power sistem.
# the data have a hourly resolution. data aviable from 1980 up to 2017, for all days of each year.

# First call the packages.

using Plots, Statistics
using DataFrames, XLSX, Query, Dates
using Clustering
using JuMP, HiGHS
using CSV
using DataFrames
using ExcelFiles
using RegularExpressions
using CairoMakie
# plotlyjs()

# declare functions

function getData(df2,deltaMin,date1,date2)
    #df2: dataframe with data
    
    df2 = @from i in df2 begin
        @where i.timeStamp >= date1 && i.timeStamp < date2
        @select {i.timeStamp, i.GHI, i.WIND}
        @collect DataFrame
    end

    df2 = dropmissing(df2)
    numDays = Int.(ceil(datetime2julian(date2)-datetime2julian(date1)))

    dataGHI = zeros(24*Int.(60/deltaMin),numDays)
    dataWIND = zeros(24*Int.(60/deltaMin),numDays)

    day_index = 0
    for d in 1:numDays
        actual_date = date1 + Dates.Day(d-1)   # hacer depender de iter
        day_index = day_index + 1
        df_day = @from i in df2 begin
            @where i.timeStamp >= actual_date && i.timeStamp < actual_date + Dates.Day(1)
            @select {i.timeStamp, i.GHI, i.WIND}
            @collect DataFrame
        end
        for i in 1:size(df_day)[1]
            time_index = Int.((Dates.hour(Dates.DateTime(df_day.timeStamp[i]))*60+Dates.minute(Dates.DateTime(df_day.timeStamp[i])))/deltaMin+1)
            dataGHI[time_index,day_index] = df_day.GHI[i]
            dataWIND[time_index,day_index] = df_day.WIND[i]
        end
    end
    return dataGHI, dataWIND
end

function cleanData(data::DataFrame)
    # Filtrar las filas que no contienen la cadena "NaN" en ninguna de las columnas
    return filter!(row -> !isnan(row.GHI), data)
end

# Acá obtengo las irradianzas y temperaturas...
df_IRR = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Sun/Antofagasta.csv", DataFrame)
ncol(df_IRR)
rename!(df_IRR,[:Date,:GLB,:DIR,:DIF,:SCT,:GHI,:DIRH,:DIFH,:DNI,:TAMB,:WIND,:SHADOW,:CLOUD])
# Crear la columna timeStamp con ceros
df_IRR.timeStamp = fill(DateTime(0), nrow(df_IRR))

# Recorrer el DataFrame y asignar DateTime a cada elemento de la columna timeStamp
for i in 1:nrow(df_IRR)
    df_IRR.timeStamp[i] = DateTime(parse(Int, df_IRR.Date[i][1:4]), parse(Int, df_IRR.Date[i][6:7]), parse(Int, df_IRR.Date[i][9:10]), parse(Int, df_IRR.Date[i][12:13]))
end

df = df_IRR[!, [:timeStamp, :GHI, :WIND]]
df = cleanData(df)

# años
years1 = []
for i in df.timeStamp
    push!(years1, year(i))
end
years = unique(years1)
println(years)

# years = [2004,2005,2006,2007,2008]
temporadas = ["Verano1"]

dict_temporadas = Dict("Verano1"=> 1)

cuatro_dias_list = []
for j in temporadas
    season = dict_temporadas[j]
    for i in years
        if j == "Verano1"
            deltaMin = 60
            time = deltaMin*[1:24]/60
            date_1 = DateTime(i,1,1,0)
            date_2 = DateTime(i,4,30,23)
            numDays = Int.(ceil(datetime2julian(date_2)-datetime2julian(date_1)))
            for m in 1:numDays-3
            # for m in 1:1
                date1 = date_1 + Dates.Day(m-1)
                date2 = date1 + Dates.Day(4)
                Data_Irr_GHI, Data_Irr_WIND = getData(df,deltaMin,date1,date2)
                
                # perfiles sol y viento 4 dias seguidos
                GHI1 = Data_Irr_GHI[:,1]
                GHI2 = Data_Irr_GHI[:,2]
                GHI3 = Data_Irr_GHI[:,3]
                GHI4 = Data_Irr_GHI[:,4]
                WIND1 = Data_Irr_WIND[:,1]
                WIND2 = Data_Irr_WIND[:,2]
                WIND3 = Data_Irr_WIND[:,3]
                WIND4 = Data_Irr_WIND[:,4]

                # generar estadisticos para esta serie de 4 dias
                # viento 
                # velocidad_max_viento1 = maximum([maximum(WIND1), maximum(WIND2)])
                # velocidad_max_viento2 = maximum([maximum(WIND3), maximum(WIND4)])
                # velocidad_max_viento_dif = abs(velocidad_max_viento1-velocidad_max_viento2)
                # velocidad_min_viento1 = minimum([minimum(WIND1), minimum(WIND2)])
                # velocidad_min_viento2 = minimum([minimum(WIND3), minimum(WIND4)])
                # velocidad_min_viento_dif = abs(velocidad_min_viento1-velocidad_min_viento2)
                velocidad_prom_viento1 = mean([mean(WIND1), mean(WIND2)])
                velocidad_prom_viento2 = mean([mean(WIND3), mean(WIND4)])
                velocidad_prom_viento_dif = abs(velocidad_prom_viento1-velocidad_prom_viento2)
                potencia_prom_solar1 = mean([mean(GHI1), mean(GHI2)])
                potencia_prom_solar2 = mean([mean(GHI3), mean(GHI4)])
                potencia_prom_solar_dif = abs(potencia_prom_solar1-potencia_prom_solar2)
                # energia_viento1 = sum([sum(WIND1), sum(WIND2)])
                # energia_viento2 = sum([sum(WIND3), sum(WIND4)])
                # energia_viento_dif = abs(energia_viento1-energia_viento2)
                # if velocidad_max_viento1 > 0
                #     factor_planta_viento1 = energia_viento1/(velocidad_max_viento1*48) 
                # else
                #     factor_planta_viento1 = 0
                # end
                # if velocidad_max_viento2 > 0
                #     factor_planta_viento2 = energia_viento2/(velocidad_max_viento1*48) 
                # else
                #     factor_planta_viento2 = 0
                # end
                # factor_planta_viento_dif = abs(factor_planta_viento1-factor_planta_viento2)
                push!(cuatro_dias_list, (i, j, potencia_prom_solar1, velocidad_prom_viento1, velocidad_prom_viento_dif, potencia_prom_solar_dif))
                # push!(cuatro_dias_list, (velocidad_max_viento1,velocidad_max_viento2,velocidad_min_viento1,velocidad_min_viento2,velocidad_prom_viento1,velocidad_prom_viento2,energia_viento1,energia_viento2,factor_planta_viento1,factor_planta_viento2))
            end
        end
    end
end

df_pre_cluster = DataFrame(cuatro_dias_list, [:Año, :Temporada, :potencia_prom_solar1, :velocidad_prom_viento1, :velocidad_prom_viento_dif, :potencia_prom_solar_dif])
# println(df_pre_cluster)

# Aplicar K-Means Clustering
df_pre_cluster_copy = df_pre_cluster[!, [:potencia_prom_solar1, :velocidad_prom_viento1, :velocidad_prom_viento_dif, :potencia_prom_solar_dif ]]
matrix_pre_cluster = Matrix(df_pre_cluster_copy)'
Result = kmeans(matrix_pre_cluster, 5, maxiter=2000, display=:none)  # Puedes cambiar el número de clusters según lo necesites
Centroides = Result.centers
Asignaciones = Result.assignments
Conteo = Result.counts
df_post_cluster = df_pre_cluster
df_post_cluster.Cluster = Asignaciones
println(df_post_cluster)
println(Centroides)
println(Conteo)











# Función para calcular la distancia euclidiana
function calcular_distancia(punto, centroide)
    return sqrt(sum((punto .- centroide) .^ 2))
end

# Calcular las distancias y la pertenencia en porcentaje
puntuacion_pertenencia = Float64[]
puntuacion_pertenencia_porcentaje = Float64[]

# Encuentra la distancia máxima (para normalizar)
distancias = Float64[]
for i in 1:nrow(df_post_cluster)
    punto = [df_post_cluster.potencia_prom_solar_max[i], df_post_cluster.potencia_prom_solar_dif[i]]
    centroide = Centroides[df_post_cluster.Cluster[i]]
    distancia = calcular_distancia(punto, centroide)
    push!(distancias, distancia)
end

# La distancia máxima en todo el conjunto de datos
d_max = maximum(distancias)

# Calcular la pertenencia en porcentaje
for i in 1:nrow(df_post_cluster)
    punto = [df_post_cluster.potencia_prom_solar_max[i], df_post_cluster.potencia_prom_solar_dif[i]]
    centroide = Centroides[df_post_cluster.Cluster[i]]
    distancia = calcular_distancia(punto, centroide)
    
    # Pertenencia en porcentaje (inversamente proporcional a la distancia)
    pertenencia_pct = 100 * (1 - distancia / d_max)
    
    # Agregar la puntuación de pertenencia y la pertenecía en porcentaje al DataFrame
    push!(puntuacion_pertenencia, distancia)
    push!(puntuacion_pertenencia_porcentaje, pertenencia_pct)
end

df_post_cluster.puntuacion_pertenencia_porcentaje = puntuacion_pertenencia_porcentaje
# Mostrar el DataFrame con la nueva columna de pertenencia en porcentaje
println(df_post_cluster)