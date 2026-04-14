# Bus Driver + RAM

Módulo de interconexión entre el core RISC-V, la memoria RAM y los
periféricos (UART, LEDs, Switches/Botones) del sistema computacional del
Laboratorio 2.

**Responsable:** Persona 2
**Versión:** 1.1

---

## Tabla de contenidos

- [1. Descripción](#1-descripción)
- [2. Estructura de archivos](#2-estructura-de-archivos)
- [3. Mapa de memoria](#3-mapa-de-memoria)
- [4. Interfaces](#4-interfaces)
  - [4.1. Core ↔ Bus Driver](#41-core--bus-driver)
  - [4.2. Bus Driver ↔ SW/BTN](#42-bus-driver--swbtn-read-only)
  - [4.3. Bus Driver ↔ LEDs](#43-bus-driver--leds-write-only)
  - [4.4. Bus Driver ↔ UART](#44-bus-driver--uart-readwrite)
  - [4.5. Bus Driver ↔ RAM (BMG)](#45-bus-driver--ram-bmg)
- [5. Convenciones importantes](#5-convenciones-importantes)
- [6. Protocolo de bus](#6-protocolo-de-bus)
- [7. Validación](#7-validación)
- [8. Dependencias](#8-dependencias)

---

## 1. Descripción

El Bus Driver implementa la lógica de interconexión entre el procesador
RISC-V (PicoRV32) y el resto del sistema memoria. Sus funciones son:

1. **Decodificar** la dirección de acceso generada por el core y activar
   la señal de selección del módulo correspondiente.
2. **Rutear** los datos de escritura y el write enable al destino
   seleccionado.
3. **Multiplexar** las respuestas de lectura y entregarlas al core.
4. **Alinear la latencia** de lectura a 1 ciclo uniforme para todos los
   destinos.
5. **Instanciar** la memoria RAM de datos (IP-Core BMG de Vivado).

---

## 2. Estructura de archivos

```
hw/bus_driver/
├── bus_driver.sv          RTL principal
├── data_ram.xci           IP-Core del BMG (25600 palabras × 32 bits)
└── README_BMG.md          Instrucciones para regenerar el IP en Vivado

tb/
└── tb_bus_driver.sv       Testbench con 16 casos de prueba
```

---

## 3. Mapa de memoria

| Rango                  | Destino             | Tamaño   | Acceso      |
|------------------------|---------------------|----------|-------------|
| `0x00000` – `0x00FFF`  | ROM (bus separado)  | 4 KiB    | Solo lectura |
| `0x02000`              | Switches/Botones    | 1 reg    | Solo lectura |
| `0x02004`              | LEDs                | 1 reg    | Solo escritura |
| `0x02010`              | UART – Control      | 1 reg    | Lectura/Escritura |
| `0x02018`              | UART – Data TX      | 1 reg    | Lectura/Escritura |
| `0x0201C`              | UART – Data RX      | 1 reg    | Solo lectura |
| `0x40000` – `0x7FFFF`  | RAM (datos)         | 100 KiB  | Lectura/Escritura |

---

## 4. Interfaces

### 4.1. Core ↔ Bus Driver

| Señal             | Dir | Ancho | Descripción                            |
|-------------------|-----|-------|----------------------------------------|
| `clk_i`           | in  | 1     | Reloj del sistema                      |
| `rst_i`           | in  | 1     | Reset síncrono, activo en alto         |
| `core_addr_i`     | in  | 32    | Dirección por byte                     |
| `core_wdata_i`    | in  | 32    | Dato a escribir                        |
| `core_we_i`       | in  | 1     | Write enable                           |
| `core_rdata_o`    | out | 32    | Dato leído (latencia 1 ciclo)          |

### 4.2. Bus Driver ↔ SW/BTN (read-only)

| Señal       | Dir | Ancho | Descripción                                  |
|-------------|-----|-------|----------------------------------------------|
| `sw_sel_o`  | out | 1     | Activo cuando `addr = 0x02000`               |
| `sw_data_i` | in  | 32    | Bits `[15:0]` = switches; `[31:16]` = 0      |

### 4.3. Bus Driver ↔ LEDs (write-only)

| Señal        | Dir | Ancho | Descripción                              |
|--------------|-----|-------|------------------------------------------|
| `led_sel_o`  | out | 1     | Activo cuando `addr = 0x02004`           |
| `led_we_o`   | out | 1     | Write enable global                      |
| `led_data_o` | out | 32    | Bits `[15:0]` se muestran en LEDs físicos |

### 4.4. Bus Driver ↔ UART (read/write)

| Señal         | Dir | Ancho | Descripción                                     |
|---------------|-----|-------|-------------------------------------------------|
| `uart_addr_o` | out | 32    | Dirección completa (UART decodifica internamente) |
| `uart_data_o` | out | 32    | Dato a escribir                                 |
| `uart_we_o`   | out | 1     | Activo solo si `addr ∈ {0x02010, 18, 1C}` y `we=1` |
| `uart_data_i` | in  | 32    | Combinacional, debe ser 0 fuera de rango        |

### 4.5. Bus Driver ↔ RAM (BMG)

| Señal   | Dir | Ancho | Descripción                          |
|---------|-----|-------|--------------------------------------|
| `clka`  | in  | 1     | Reloj                                |
| `wea`   | in  | 1     | Write enable                         |
| `addra` | in  | 15    | Dirección por palabra (25600 palabras) |
| `dina`  | in  | 32    | Dato a escribir                      |
| `douta` | out | 32    | Dato leído (latencia 1 ciclo)        |

---

## 5. Convenciones importantes

### 5.1. Polaridad de reset

| Módulo              | Convención       |
|---------------------|------------------|
| `riscv_core`        | Activo en alto   |
| `bus_driver`        | Activo en alto   |
| `led_peripheral`    | Activo en alto   |
| `sw_btn_peripheral` | Activo en alto   |
| `uart_peripheral`   | **Activo en bajo** |

> ⚠️ En el `top.sv` final hay que conectar `~rst_i` al puerto `rst_n` del UART.

### 5.2. Alineación de direcciones

El core usa direcciones **por byte** (32 bits completos). La RAM (BMG) usa
direcciones **por palabra** (15 bits). El bus driver hace la conversión
tomando los bits `[16:2]` y descartando los bits `[1:0]` (alineación de
palabra de 32 bits = 4 bytes).

### 5.3. Latencia uniforme

Todas las operaciones de lectura tienen **latencia de 1 ciclo**
independientemente del destino. Esto es requerido por `riscv_core.sv`, que
ya implementa el `mem_ready` con un flip-flop de 1 ciclo.

---

## 6. Protocolo de bus

Se implementa un **AXI-Lite simplificado** (single-channel) que adopta los
principios del estándar sin los 5 canales completos:

- Handshake `valid/ready` interno (manejado por PicoRV32 vía `mem_valid`/`mem_ready`)
- Separación lógica de fases dirección/datos
- Wait states soportados (RAM 1 ciclo, periféricos combinacional + registro)
- Sin bursts: transacciones single de 32 bits
- Decodificación por dirección mapeada a memoria

Esta aproximación es equivalente al estilo usado en buses internos de
Cortex-M0/M3 y es suficiente para cumplir los requisitos del instructivo.

---

## 7. Validación

El testbench `tb_bus_driver.sv` ejecuta **16 casos de prueba** cubriendo:

| Test | Cobertura                                            |
|------|------------------------------------------------------|
| 1    | Escritura/lectura en 3 direcciones de la RAM         |
| 2    | Lectura del valor físico de los switches             |
| 3    | Escritura a LEDs llega al pin físico                 |
| 4    | Lectura/escritura de los 3 registros UART            |
| 5    | Direcciones no mapeadas devuelven `0x00000000`       |
| 6    | Escrituras no mapeadas no afectan periféricos        |
| 7    | RAM funciona correctamente tras accesos a periféricos |
| 8    | Límites de la RAM (primera y última posición)        |

**Resultado:** 16/16 tests pasados.

### Cómo ejecutar el testbench

1. Abrir el proyecto en Vivado.
2. Setear `tb_bus_driver` como top de simulación (click derecho → Set as Top).
3. Flow Navigator → Run Simulation → Run Behavioral Simulation.
4. En la Tcl Console del simulador: `run all`.
5. Verificar en la consola: `=== TODOS LOS TESTS PASARON ===`.

---

## 8. Dependencias

### Módulos instanciados

- `data_ram` (IP-Core de Vivado, generado a partir de `data_ram.xci`)

### Módulos que dependen de este

- `top.sv` — instancia el `bus_driver` como interconexión central
- `led_peripheral.sv` — conectado a través de `led_sel_o`, `led_we_o`, `led_data_o`
- `sw_btn_peripheral.sv` — conectado a través de `sw_sel_o`, `sw_data_i`
- `uart_peripheral.sv` — conectado a través de `uart_addr_o`, `uart_data_o`, `uart_we_o`, `uart_data_i`

### Herramientas

- Vivado 2025.2
- Block Memory Generator v8.4
