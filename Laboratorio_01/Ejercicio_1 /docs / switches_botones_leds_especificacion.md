# Ejercicio 1 – Switches y LEDs

## Descripción

Este ejercicio consiste en diseñar un módulo digital combinacional que reciba como entrada 4 interruptores físicos de la FPGA Nexys4 DDR y muestre en 4 LEDs el complemento a 2 del valor ingresado.

## Objetivo

Implementar un bloque completamente sintetizable que:

- Reciba un bus de 4 bits desde los switches.
- Calcule el complemento a 2 del valor.
- Muestre el resultado en los LEDs.
- No genere latches.
- Sea validado mediante testbench autocheck.

## Especificaciones técnicas

- Entrada: `sw[3:0]`
- Salida: `led[3:0]`
- Operación:  
  Complemento a 2  
  \[
  Y = (\sim X) + 1
  \]

## Tipo de diseño

- Lógica combinacional.
- Descripción en SystemVerilog.
- Diseño sintetizable para FPGA.

## Validación

Se desarrolló un testbench autocheck que verifica las 16 combinaciones posibles de entrada y compara el resultado con el valor teórico esperado.

