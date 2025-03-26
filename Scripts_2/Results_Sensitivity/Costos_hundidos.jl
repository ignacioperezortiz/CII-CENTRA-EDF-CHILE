# script para estimar los costos hundidos que no fueron considerados en las tablas de resultados del valor de los LDES para el sistema.

# leer archivo C:\Users\Ignac\Trabajo_Centra\Catedra-LDES\CII-Centra-EDF\Estudio_Oficial\Sensibilidades\OK\Corridos\CasoBase\RL\inputs\gen_build_predetermined.csv 

# leer archivo C:\Users\Ignac\Trabajo_Centra\Catedra-LDES\CII-Centra-EDF\Estudio_Oficial\Sensibilidades\OK\Corridos\CasoBase\RL\inputs\gen_info.csv

# leer archivo C:\Users\Ignac\Trabajo_Centra\Catedra-LDES\CII-Centra-EDF\Estudio_Oficial\Sensibilidades\OK\Corridos\CasoBase\RL\inputs\gen_build_costs.csv

# filtrar el primer archivo. valores de la columna build_year >=2024

# para cada fila, seleccionar el nombre del proyecto disponible en la columna "GENERATION_PROJECT"

# buscar en la columna "GENERATION_PROJECT" del ultimo archivo. e identificar su tecnología de generación disponible en la columna "gen_energy_source".

# conociendo su tecnología, anda a buscar el costo de dicha tecnología para el periodo en particular, definido en el arreglo nombrado por ti que contiene los costos para cada tecnología para cada perido .

# teniendo el costo del proyecto y la capacidad (columna build_gen_predetermined del primer archivo) puedes multiplicar ambos valores para estimar el costo total del proyecto. Si el periodo en el que se construye el proyecto (columna build_year del primer archivo) no es 2024, entonces debes traer el costo a valor presente (2024) considerando una tasa del 0,06.

# por ultimo, necesito que para cada tecnología sumes el total de inversión de todos los proyectos de dicha tecnología en valor presente y me entregues un dataframe de resultado que contenga en las columnas el nombre de la tecnología y en la primera fila se encuentre el costo total al año 2024. 

# para construir el arreglo con los costos de cada tecnología considera las siguientes tecnologías y los siguientes costos:

# como hay costos distintos para centrales eolicas por ejemplo por la penalización del 15% y temas así, para no tener que ir a buscar los costos de manera manual quizas calcular los promedios, pero considerando unicamente los que tienen costos de inversión mayor a 0. 

# escenario RL:

# escenario CN: 

# escenario TA: 