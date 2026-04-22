# Registro de asistencia con Inteligencia Artificial

Este documento registra de forma transparente el uso de herramientas de IA
generativa durante el desarrollo de este proyecto, según lo solicitado por
el docente del curso EL3313.

## Políticas seguidas

1. **Toda línea de código generada con IA fue revisada y comprendida por el
   autor** antes de incorporarla al proyecto. 
2. Las **decisiones de arquitectura** (mapa de memoria, selección del core
   `picorv32_axi`, número de slaves AXI-Lite, convención de señales) fueron
   tomadas por el autor.
3. Los **testbenches** se validaron ejecutándolos en Vivado XSim; los casos
   de prueba críticos se diseñaron manualmente.
4. La IA se usó principalmente como asistente de (a) generación de esqueletos,
   (b) revisión y debug de bugs, (c) explicación de estándares (AXI-Lite,
   ABI RISC-V, timing en FPGAs), (d) apoyo en el bring-up de hardware.

## Herramientas utilizadas

- **Claude (Anthropic)** — modelos Claude Sonnet 4.6 y Claude Opus 4 (vía
  claude.ai, en múltiples sesiones a lo largo del desarrollo).

## Registro por archivo

### RTL — Lógica sintetizable

| Archivo | Tipo de asistencia | Alcance de la IA | Validación del autor |
|---|---|---|---|
| `rtl/top.sv` | Generación + debug extenso en HW | Esqueleto de instanciación, conexión del bus, fix de LEDs de debug (`pll_locked`, `rst_n`, `core_trap`) | Revisado manualmente; probado en FPGA Nexys4 DDR hasta validación completa |
| `rtl/bus/axil_defs.svh` | Generación | Parámetros globales del bus y mapa de memoria (`NUM_SLAVES`, `SLAVE_IDX_*`, rangos de direcciones) | Revisado; contrastado con el mapa de memoria del enunciado |
| `rtl/bus/axil_interconnect.sv` | Generación + debug | Decoder 1M→5S con lógica DECERR para direcciones no mapeadas | Testbench manual: 36/36 checks; simulado con rutas a los 5 slaves |
| `rtl/core/picorv32.v` | **Sin IA** — terceros | Core RV32I de YosysHQ (repositorio público); solo se seleccionó la variante `picorv32_axi` | Parámetros revisados contra documentación oficial de YosysHQ |
| `rtl/memory/rom_axil.sv` | Generación | Wrapper AXI-Lite con `$readmemh` (versión inferrable para simulación) | No usado en síntesis; validado en sim |
| `rtl/memory/ram_axil.sv` | Generación | Wrapper AXI-Lite con byte-write-enable inferrable | No usado en síntesis; validado en sim |
| `rtl/memory/rom_axil_with_ip.sv` | Generación | Wrapper que adapta el IP `rom_program` (Block Memory Generator) a AXI-Lite | Probado en FPGA; depurado el problema de cache del IP en Vivado |
| `rtl/memory/ram_axil_with_ip.sv` | Generación | Wrapper que adapta el IP `data_ram` a AXI-Lite con byte-enables | Probado en FPGA |
| `rtl/peripherals/gpio_leds_axil.sv` | Generación | Registro de 12 bits RW mapeado en AXI-Lite | Testbench manual: 7/7 checks |
| `rtl/peripherals/gpio_sw_btn_axil.sv` | Generación | Switches (16) + botones (4), con sincronizador 2FF y debounce 10 ms | Testbench manual: 4/4 checks; probado en FPGA con switches físicos |
| `rtl/peripherals/uart/uart_axil.sv` | Generación | Wrapper AXI-Lite para TX/RX; registros CTRL, TX, RX; auto-clear de `send` | Testbench manual: 7/7 checks |
| `rtl/peripherals/uart/uart_baud_gen.sv` | Generación | Generador de `tx_tick` a partir de `CLK_FREQ_HZ` y `BAUD_RATE` | Validado calculando divisor manualmente para 50 MHz / 9600 baud |
| `rtl/peripherals/uart/uart_tx.sv` | **Sin IA** — reutilizado de Lab 1 | — | — |
| `rtl/peripherals/uart/uart_rx.sv` | Revisión y reescritura | RX original usaba tick 16× separado con drift acumulado; reescrito con `BIT_PERIOD` en ciclos de reloj directos | Testbench de loopback: 8 bytes OK; probado en FPGA |
| `rtl/util/synchronizer.sv` | **Sin IA** | — | — |
| `rtl/util/debouncer.sv` | Revisión parcial | Explicación del cálculo del contador para 50 MHz / 10 ms | Parámetros recalculados manualmente (`DEBOUNCE_CYCLES = 500_000`) |
| `rtl/util/reset_sync.sv` | Generación | Reset async-assert, sync-deassert con 3 etapas; atributo `ASYNC_REG` | Revisado; comportamiento verificado en simulación |

### Simulación

| Archivo | Tipo de asistencia | Alcance de la IA | Validación del autor |
|---|---|---|---|
| `sim/common/axil_master_bfm.sv` | Generación | Bus Functional Model AXI-Lite para testbenches (tareas `axil_write`, `axil_read`) | Validado comparando transacciones contra IP de Xilinx en sim |
| `sim/tb_axil_interconnect.sv` | Generación parcial + asserts manuales | Estructura general; stimulus y verificación de DECERR | 36/36 checks; casos de error de dirección escritos por el autor |
| `sim/tb_gpio_leds_axil.sv` | Generación parcial | Estructura del testbench | 7/7 checks |
| `sim/tb_gpio_sw_btn_axil.sv` | Generación parcial | Estructura + debounce acelerado por parámetro | 4/4 checks |
| `sim/tb_uart_axil.sv` | Generación parcial | Estructura; casos TX, RX, send auto-clear | 7/7 checks |
| `sim/tb_uart_loopback.sv` | Generación parcial | Loopback de 8 bytes con verificación byte a byte | 8/8 bytes OK (0x5A, 0xA5, 0x00, 0xFF, 0x01, 0x80, 0x55, 0xAA) |

### Software (ensamblador RISC-V)

| Archivo | Tipo de asistencia | Alcance de la IA | Validación del autor |
|---|---|---|---|
| `sw/asm/hello_blink.s` | Generación completa | Programa de test: envía "READY\r\n" por UART, refleja switches en LEDs, hace echo de bytes recibidos | Usado durante el bring-up completo del SoC; validado en FPGA |
| `sw/asm/calc.s` | Generación completa | Calculadora UART: parseo de operandos (hasta 4 dígitos), suma/resta, eco de entrada, `print_int` con división por restas repetidas (RV32I puro, sin extensión M) | Revisado línea a línea por el autor; validado en FPGA |
| `sw/build/main.coe` | Generado por toolchain | Salida del ensamblador convertida a formato COE para Block Memory Generator | Verificado comparando primeras y últimas palabras con el fuente ASM |

### IP, scripts y restricciones

| Archivo | Tipo de asistencia | Alcance de la IA | Validación del autor |
|---|---|---|---|
| `ip/clk_wiz_main.tcl` | Generación | Configuración del PLL Clocking Wizard (100 MHz → 50 MHz) | Verificado contra Product Guide PG065 de Xilinx |
| `ip/rom_program.tcl` | Generación | Block Memory Generator configurado como ROM simple-puerto con archivo `.coe` | Depurado extensamente; resuelto problema de cache de IP en Vivado |
| `ip/data_ram.tcl` | Generación | Block Memory Generator como RAM con byte-write-enable de 4 bits | Verificado contra Product Guide PG058 |
| `scripts/create_project.tcl` | Generación | Script Vivado que crea el proyecto, agrega fuentes, IPs y restricciones desde cero | Ejecutado múltiples veces; funcional en Vivado 2024.1 |
| `constraints/nexys4ddr.xdc` | **Sin IA** — referencia Digilent | Pines tomados del XDC oficial de Digilent para Nexys4 DDR | Verificado pin a pin contra el manual de la placa |
| `AI_USAGE.md` | Plantilla + actualización | Estructura del documento | Contenido completado honestamente por el autor |
| `README.md` | Generación de plantilla | Estructura del documento | Contenido técnico adaptado por el autor |

## Problemas detectados en código generado por IA y corregidos

Durante el desarrollo se identificaron y corrigeron los siguientes errores en
código producido por IA:

1. **Handshake AXI-Lite incorrecto**: `awready`/`wready` no se deasserteaban
   correctamente durante la fase `bvalid`, lo que hubiera causado deadlock en
   transacciones consecutivas.
2. **Drift acumulado en UART RX**: el receptor original usaba un generador de
   tick 16× independiente; los divisores no enteros generaban desviación
   acumulada. Solución: reescribir con `BIT_PERIOD` en ciclos de reloj directos.
3. **Incompatibilidad con XSim 2024.1**: asignaciones NBA a arrays asociativos
   no soportadas; resuelto usando asignación bloqueante en los BFMs de sim.
4. **`fork`/`join_any` en XSim**: fallaban silenciosamente; reemplazados por
   polling plano con contador de seguridad.
5. `` `default_nettype none `` en síntesis**: causaba errores "net type must be
   explicitly specified" en picorv32.v (terceros); removido de todos los
   archivos `.sv` propios.
6. **Cache del IP `rom_program` en Vivado**: el checkpoint `.dcp` del IP no se
   regeneraba aunque el `.coe` cambiara; resuelto borrando manualmente
   `.gen/sources_1/ip/rom_program*/` y forzando `generate_target all` +
   `synth_ip`.
7. **`core_pc` nunca actualizado en `top.sv`**: el bloque `always_ff` sin
   rama `else` dejaba el registro en cero permanentemente; corregido
   conectando señales de diagnóstico reales (`pll_locked`, `rst_n`,
   `core_trap`) a los LEDs de debug.

## Resumen cualitativo

La IA aceleró significativamente la escritura de boilerplate (interfaces
AXI-Lite, scripts TCL, estructura de testbenches, rutinas UART en
ensamblador). Sin embargo, el **trabajo de diseño** — arquitectura del SoC,
mapa de memoria, selección del core, convención de señales, orden del
bring-up, decisiones de debug en hardware — fue realizado por el autor.

Los errores listados arriba refuerzan que el código generado por IA requiere
revisión crítica antes de usarse: ninguno hubiera sido detectado por la misma
IA que lo generó sin un testbench o prueba en hardware que lo ejercitara.



Walter Alfaro Ulate — 21 de abril de 2026
