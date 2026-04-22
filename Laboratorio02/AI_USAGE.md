# Registro de asistencia con Inteligencia Artificial

Este documento registra de forma transparente el uso de herramientas de IA
generativa durante el desarrollo de este proyecto, según lo solicitado por
el docente del curso EL3313.

## Políticas seguidas

1. **Toda línea de código generada con IA fue revisada, comprendida y
   adaptada por el autor** antes de incorporarla al proyecto. No se ha
   incluido código cuya funcionalidad no se entienda plenamente.
2. Los **testbenches** y los **casos de prueba críticos** se escribieron y/o
   validaron manualmente para evitar que la misma IA que generó el código
   certifique su propio resultado (riesgo de sesgo de confirmación).
3. Todas las **decisiones de arquitectura** (mapa de memoria, selección del
   core, convención de señales, división de módulos) fueron tomadas por el
   autor.
4. La IA se usó principalmente como asistente de (a) generación de esqueletos,
   (b) revisión de bugs, (c) explicación de estándares (AXI-Lite, ABI RISC-V),
   (d) formateo de documentación.

## Herramientas utilizadas

- **Claude (Anthropic)** — modelo Claude Opus 4.7, vía claude.ai.

## Registro por archivo

| Archivo                              | Tipo de asistencia                       | Alcance de la IA                                      | Validación del autor                          |
|--------------------------------------|------------------------------------------|-------------------------------------------------------|-----------------------------------------------|
| `rtl/top.sv`                         | Generación inicial + revisión            | Esqueleto de instanciación y conexión del bus         | Revisado, ajustado nombres de señales, probado en simulación y FPGA |
| `rtl/bus/axil_interconnect.sv`       | Generación + debug                       | Decoder de direcciones según mapa de memoria          | Testbench manual; probado con 4 slaves        |
| `rtl/peripherals/uart/uart_axil.sv`  | Generación de FSM slave AXI-Lite         | Máquina de estados de las 5 canales AXI               | Comparado contra PG059 de Xilinx; TB manual   |
| `rtl/peripherals/uart/uart_tx.sv`    | Sin IA (reutilizado de Lab 1)            | —                                                     | —                                             |
| `rtl/peripherals/uart/uart_rx.sv`    | Sin IA (reutilizado de Lab 1)            | —                                                     | —                                             |
| `rtl/peripherals/gpio_leds_axil.sv`  | Generación inicial                       | Registro único de 16 bits                             | Testbench manual                              |
| `rtl/peripherals/gpio_sw_btn_axil.sv`| Generación + integración con debouncer   | Conexión del sincronizador y antirebote               | Testbench manual; probado en FPGA             |
| `rtl/util/synchronizer.sv`           | Sin IA                                   | —                                                     | —                                             |
| `rtl/util/debouncer.sv`              | Revisión                                 | Explicación del cálculo del contador para 50 MHz      | Parámetros recalculados manualmente           |
| `rtl/memory/rom_axil.sv`             | Generación del wrapper                   | Envoltura AXI-Lite del IP Block Memory Generator      | Testbench manual                              |
| `rtl/memory/ram_axil.sv`             | Generación del wrapper                   | Envoltura AXI-Lite del IP Block Memory Generator      | Testbench manual                              |
| `sim/common/axil_master_bfm.sv`      | Generación                               | Bus Functional Model para pruebas AXI-Lite            | Validado contra IP de Xilinx en simulación    |
| `sim/tb_*.sv`                        | Parcial (estructura), asserts manuales   | Estructura general del testbench                      | Stimulus y asserts escritos por el autor      |
| `sw/tools/rv32i_asm.py`              | Generación inicial + iteración           | Ensamblador básico RV32I a COE                        | Validado comparando salida con GNU as         |
| `sw/asm/calculator.s`                | Sin IA (escrito por el autor)            | —                                                     | Validado con Spike antes de FPGA              |
| `scripts/create_project.tcl`         | Generación                               | Script Vivado automatizado                            | Ejecutado múltiples veces; funciona           |
| `ip/*.tcl`                           | Generación                               | Configuración de clk_wiz y blk_mem_gen                | Verificado contra Product Guides de Xilinx    |
| `constraints/nexys4ddr.xdc`          | Sin IA (referencia: manual Digilent)     | —                                                     | —                                             |
| `docs/informe.md`                    | Revisión de redacción                    | Corrección de estilo y gramática                      | Contenido técnico escrito por el autor        |
| `README.md`                          | Generación de plantilla                  | Estructura del documento                              | Contenido adaptado por el autor               |
| `AI_USAGE.md`                        | Plantilla                                | Este mismo archivo                                    | Completado honestamente por el autor          |

## Resumen cualitativo

La IA aceleró significativamente la **escritura de boilerplate** (interfaces
AXI-Lite, scripts TCL de Vivado, estructura de testbenches). Sin embargo, el
**trabajo de diseño** —decidir la arquitectura, el mapa de memoria, la
convención de nombres, la selección de `picorv32_axi` sobre la variante
nativa, el orden de bring-up— fue realizado manualmente.

Se detectaron errores en código generado por IA que fueron corregidos:
- Handshake AXI-Lite sin deasserción de `awready`/`wready` durante la
  respuesta `bvalid` (hubiera causado deadlock).
- Parámetro `CLK_FREQ_HZ` inconsistente entre el UART y el PLL.
- Reset mezclado (`rst_n` vs `aresetn`) en el módulo de debounce.

Estas correcciones refuerzan la importancia de no aceptar código generado
sin revisión crítica.

## Declaración

El autor de este proyecto asume **responsabilidad completa** por todo el
código contenido en este repositorio, independientemente de su origen, y
declara comprender cada línea entregada.

[Nombre completo] — [Fecha]
