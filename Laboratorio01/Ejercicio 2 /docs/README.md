## Ejercicio 2 – Multiplexor 4:1 Parametrizable

1. Introducción

En este ejercicio se diseña un multiplexor 4:1 parametrizable utilizando un lenguaje de descripción de hardware (SystemVerilog/Verilog). El objetivo es implementar un módulo completamente combinacional cuyo ancho de datos sea configurable mediante un parámetro.

El diseño debe ser sintetizable y funcionar correctamente para distintos tamaños de bus de datos.

2. Descripción general del módulo

El multiplexor 4:1 posee:

- Cuatro entradas de datos:
  - d0
  - d1
  - d2
  - d3
- Una señal de selección de 2 bits:
  - sel[1:0]
- Una salida:
  - y
- Un parámetro:
  - WIDTH (define el ancho del bus)

El módulo selecciona una de las cuatro entradas y la dirige a la salida según el valor de la señal de selección.

El circuito es completamente combinacional, es decir, la salida depende únicamente de los valores actuales de las entradas y del selector.

3. Parámetro WIDTH

El parámetro WIDTH define el número de bits de cada entrada y de la salida.

Formalmente:

- d0, d1, d2, d3 ∈ [WIDTH-1:0]
- y ∈ [WIDTH-1:0]

El diseño debe funcionar correctamente para los siguientes valores:

- WIDTH = 4
- WIDTH = 8
- WIDTH = 16

Esto permite reutilizar el mismo módulo sin modificar su estructura interna.

4. Tabla de verdad

El comportamiento lógico del multiplexor se define mediante la siguiente tabla:

| sel[1:0] | Salida y |
|----------|----------|
| 00       | d0       |
| 01       | d1       |
| 10       | d2       |
| 11       | d3       |

La salida copia exactamente el valor de la entrada seleccionada.

5. Diagrama de bloques

Representación estructural del módulo:

   <img width="664" height="542" alt="image" src="https://github.com/user-attachments/assets/da6e4ad0-96a7-4c6e-8761-3bc5565f0ae5" />


 6. Consideraciones de diseño

- El módulo debe ser completamente combinacional.
- No deben generarse elementos de memoria (latches).
- Debe ser completamente sintetizable.
- Se debe incluir un caso por defecto para evitar inferencia de hardware no deseado.

7. Conclusión

El multiplexor 4:1 parametrizable permite seleccionar dinámicamente una de cuatro entradas de datos de ancho configurable. Su implementación correcta garantiza reutilización, claridad estructural y cumplimiento de los principios de diseño combinacional.
