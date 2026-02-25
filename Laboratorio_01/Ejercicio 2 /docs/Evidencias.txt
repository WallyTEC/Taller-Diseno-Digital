Resultados de Simulación

La simulación del módulo mux4to1 fue ejecutada mediante el banco de pruebas desarrollado en SystemVerilog.

Durante la ejecución, el testbench realizó pruebas automáticas para tres configuraciones distintas del parámetro WIDTH:

WIDTH = 4

WIDTH = 8

WIDTH = 16

Para cada ancho de datos se generaron 50 conjuntos de datos pseudoaleatorios, evaluando las cuatro posibles combinaciones del selector (00, 01, 10, 11). Esto resultó en un total de 200 verificaciones por cada ancho (50 × 4 combinaciones).

Los resultados obtenidos fueron:

PASS WIDTH=4 (200 verificaciones)

PASS WIDTH=8 (200 verificaciones)

PASS WIDTH=16 (200 verificaciones)

El mensaje final:

"TODAS LAS PRUEBAS PASARON (4, 8, 16)"

confirma que el módulo se comporta correctamente para todos los casos evaluados.

Además, la simulación finalizó sin errores ni advertencias críticas, lo que valida el correcto funcionamiento del diseño antes de la etapa de síntesis.

Adjuta imagen de la consola.
