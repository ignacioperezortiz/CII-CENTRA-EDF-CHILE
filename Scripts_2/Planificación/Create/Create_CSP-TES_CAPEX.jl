using XLSX
using DataFrames
using CSV

# Define los periodos de inversión
periodos = [2018, 2020, 2023, 2026, 2029, 2030, 2031, 2033, 2040, 2050]

# Ruta del archivo Excel de entrada
url = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_CSP-TES/Nombres_csp-tes.xlsx"

# Lee el archivo Excel y extrae los nombres de los proyectos
data = XLSX.readxlsx(url)
nombres_proyectos = data["Hoja1"][:, 1]  # Asegúrate de que el nombre de la hoja sea correcto

# Crea un DataFrame para almacenar los resultados
resultados = DataFrame(nombre=String[], periodo=Int[])

# Llena el DataFrame con los nombres de proyectos y periodos
for nombre in nombres_proyectos
    for periodo in periodos
        push!(resultados, (nombre, periodo))
    end
end

# Define la ruta para el archivo CSV de salida
output_path = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/CAPEX_csp_tes.csv"

# Exporta el DataFrame a un archivo CSV
CSV.write(output_path, resultados)

println("Archivo CSV generado en: $output_path")









# parte del script para crear sf_power_output.csv 

# Ruta del archivo Excel de entrada
url = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_CSP-TES/Nombres_csp-tess.xlsx"

# Lee el archivo Excel y extrae los nombres de los proyectos
data = XLSX.readxlsx(url)
nombres_proyectos = data["Hoja1"][:, 1]  # Asegúrate de que el nombre de la hoja sea correcto

url2 = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/inputs/timepoints.csv"
timepoints_df = CSV.read(url2, DataFrame)
timepoints = timepoints_df[:,1]

# Generar DataFrame para el CSV de salida
output_data = DataFrame(nombre = String[], timepoint = Int[], power = Int[])

# Llenar el DataFrame con las combinaciones de nombres y timepoints
for nombre in nombres_proyectos
    for timepoint in timepoints
        push!(output_data, (nombre, timepoint, 0))  # 0 para la columna power
    end
end

# Ruta del archivo CSV de salida
output_csv_path = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/sf_power_output.csv"

# Guardar el DataFrame en un archivo CSV
CSV.write(output_csv_path, output_data)