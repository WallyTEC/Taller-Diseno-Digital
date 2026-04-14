# Caracterización del Bus Driver y Memoria RAM

**Lab 2 — EL3313 — Persona 2 (RAM + Bus Driver)**

Este documento complementa la documentación técnica del sistema
computacional descrito en el instructivo. Contiene:

1. Correspondencia entre nombres del instructivo y del código.
2. Tabla de verdad del decodificador de direcciones.
3. Tabla del multiplexor de lectura.
4. Diagrama de bloques detallado del bus driver.
5. Tabla de latencias.
6. Cobertura del instructivo.

---

## 1. Correspondencia de nombres (instructivo ↔ código)

### 1.1. Core RISC-V (Figura 3 del instructivo)

| Señal en el instructivo  | Señal en el código         | Módulo donde aparece | Descripción                                      |
|--------------------------|----------------------------|----------------------|--------------------------------------------------|
| `clk_i`                  | `clk_i`                    | `riscv_core`         | Reloj del sistema                                |
| `rst_i`                  | `rst_i`                    | `riscv_core`         | Reset síncrono, activo en alto                   |
| `ProgAddress_o[31:0]`    | `ProgAddress_o[31:0]`      | `riscv_core`         | Dirección de instrucción hacia la ROM            |
| `ProgIn_i[31:0]`         | `ProgIn_i[31:0]`           | `riscv_core`         | Instrucción leída desde la ROM                   |
| `DataAddress_o[31:0]`    | `DataAddress_o[31:0]`      | `riscv_core`         | Dirección de dato hacia bus driver               |
| `DataOut_o[31:0]`        | `DataOut_o[31:0]`          | `riscv_core`         | Dato a escribir hacia bus driver                 |
| `DataIn_i[31:0]`         | `DataIn_i[31:0]`           | `riscv_core`         | Dato leído desde bus driver                      |
| `we_o`                   | `we_o`                     | `riscv_core`         | Write enable                                     |

> En este punto los nombres coinciden al 100 %.

### 1.2. Bus Driver (bloque central implícito en Figura 2)

El instructivo usa etiquetas genéricas de flechas (**address**, **write**,
**read**) para representar los buses. En el código estas flechas se
materializan así:

| Flecha del diagrama (Fig. 2)      | Señal en el bus_driver (lado core)  | Señal física equivalente               |
|-----------------------------------|-------------------------------------|----------------------------------------|
| Flecha roja **address**           | `core_addr_i[31:0]`                 | Conectada a `riscv_core.DataAddress_o` |
| Flecha verde **write** (datos)    | `core_wdata_i[31:0]`                | Conectada a `riscv_core.DataOut_o`     |
| Flecha verde **write** (enable)   | `core_we_i`                         | Conectada a `riscv_core.we_o`          |
| Flecha celeste **read**           | `core_rdata_o[31:0]`                | Conectada a `riscv_core.DataIn_i`      |

### 1.3. RAM de datos (bloque "Data Memory (RAM)" en Figura 2)

El IP-Core (Block Memory Generator) tiene puertos que no coinciden con los
nombres del instructivo. Equivalencia:

| Flecha del diagrama (Fig. 2)  | Puerto del BMG (`data_ram`) | Ancho  | Generada por              |
|-------------------------------|-----------------------------|--------|---------------------------|
| **address** (entrada a RAM)   | `addra`                     | 15     | `bus_driver.ram_addr`     |
| **write** (dato entrada)      | `dina`                      | 32     | `bus_driver.core_wdata_i` |
| **write** (enable)            | `wea`                       | 1      | `bus_driver.ram_we`       |
| **read** (salida al core)     | `douta`                     | 32     | `bus_driver.ram_dout`     |
| —                             | `clka`                      | 1      | `bus_driver.clk_i`        |

> **Nota sobre `addra`:** el instructivo usa direcciones por byte (32 bits
> completos). El BMG usa direcciones por palabra (15 bits para 25600 palabras).
> El bus driver hace la conversión tomando los bits `[16:2]` de la dirección
> del core, descartando los bits `[1:0]` (alineación de palabra).

### 1.4. Periféricos (bloques de la derecha en Figura 2)

| Periférico del instructivo | Módulo del código         | Dirección en el mapa            |
|----------------------------|---------------------------|---------------------------------|
| **Switches/Botones**       | `sw_btn_peripheral`       | `0x02000`                       |
| **LEDs**                   | `led_peripheral`          | `0x02004`                       |
| **Interfaz UART A**        | `uart_peripheral`         | `0x02010`, `0x02018`, `0x0201C` |

---

## 2. Tabla de verdad del decodificador de direcciones

El bloque combinacional de selección genera cuatro señales one-hot
(`sel_ram`, `sel_sw`, `sel_led`, `sel_uart`) a partir de la dirección
entrante. Rangos de interés:

| `core_addr_i[19:18]` | `core_addr_i[19:12]` | `core_addr_i[7:0]`   | `sel_ram` | `sel_sw` | `sel_led` | `sel_uart` | Destino         |
|:--------------------:|:--------------------:|:--------------------:|:---------:|:--------:|:---------:|:----------:|-----------------|
| `01`                 | `0x40`–`0x7F`        | X                    | **1**     | 0        | 0         | 0          | RAM             |
| `00`                 | `0x02`               | `0x00`               | 0         | **1**    | 0         | 0          | SW/BTN          |
| `00`                 | `0x02`               | `0x04`               | 0         | 0        | **1**     | 0          | LEDs            |
| `00`                 | `0x02`               | `0x10`               | 0         | 0        | 0         | **1**      | UART (control)  |
| `00`                 | `0x02`               | `0x18`               | 0         | 0        | 0         | **1**      | UART (data 1)   |
| `00`                 | `0x02`               | `0x1C`               | 0         | 0        | 0         | **1**      | UART (data 2)   |
| `00`                 | `0x02`               | `0x08`,`0x0C`,`0x14` | 0         | 0        | 0         | 0          | No mapeada      |
| X                    | otro valor           | X                    | 0         | 0        | 0         | 0          | No mapeada      |

**Propiedad (demostrada por construcción):**
`sel_ram + sel_sw + sel_led + sel_uart ≤ 1` (siempre cero o uno activos,
mutuamente exclusivos).

Esta propiedad habilita el uso de `unique case (1'b1)` en el mux de lectura.

---

## 3. Tabla del multiplexor de lectura

El mux selecciona la fuente del dato entregado al core según los selectores
**registrados** (con sufijo `_q`). El registro se necesita porque la RAM
del BMG tiene latencia 1 ciclo, mientras que los periféricos responden
combinacionalmente.

| `sel_ram_q` | `sel_sw_q` | `sel_uart_q` | `core_rdata_o`       | Notas                        |
|:-----------:|:----------:|:------------:|----------------------|------------------------------|
| 1           | 0          | 0            | `ram_dout`           | Dato de la RAM               |
| 0           | 1          | 0            | `sw_data_q`          | Valor registrado de switches |
| 0           | 0          | 1            | `uart_data_q`        | Registro UART (ctrl/rx/tx)   |
| 0           | 0          | 0            | `32'h00000000`       | Dirección no mapeada         |

**Observación:** los LEDs no aparecen en esta tabla porque son **write-only**
(el instructivo no requiere que el CPU pueda leer el estado de los LEDs).

---

## 4. Diagrama de bloques interno del bus driver

```
                        ┌─────────────────────────────────┐
  core_addr_i [31:0] ──▶│  DECODIFICADOR COMBINACIONAL    │
                        │  (sec. 1 del bus_driver)        │
                        └──┬──────┬──────┬──────┬─────────┘
                           │      │      │      │
                       sel_ram sel_sw sel_led sel_uart
                           │      │      │      │
  core_we_i  ───────┬──────┤      │      │      │
                    │      ▼      │      │      ▼
                    │    ┌─────┐  │      │   ┌─────────┐
                    │    │ AND │  │      │   │   AND   │
                    │    └──┬──┘  │      │   └────┬────┘
                    │       │     │      │        │
                    │       ▼     ▼      ▼        ▼
                    │    ram_we  sw_sel_o led_sel_o uart_we_o
                    │       │
                    │       ▼
                    │    ┌──────────────┐
  core_wdata_i ────┬┼───▶│  dina        │
                   ││    │  DATA_RAM    │
  core_addr_i[16:2]┼┼───▶│  addra (BMG) │  douta ──▶ ram_dout
                   ││    └──────────────┘              │
                   ││                                  │
                   │└──────────────▶ led_data_o        │
                   └───────────────▶ uart_data_o       │
                                                       │
                       ┌───────────────────────────────┘
                       │
                       │   sw_data_i, uart_data_i (combinacionales)
                       │         │              │
                       ▼         ▼              ▼
                    ┌─────────────────────────────────┐
                    │   REGISTRO DE ALINEACIÓN        │
                    │   (sec. 4 del bus_driver)       │
                    │   ram_dout no se registra       │
                    │   (el BMG ya tiene latencia 1)  │
                    └──┬──────────┬──────────┬────────┘
                       │          │          │
                  sel_*_q     sw_data_q  uart_data_q
                       │          │          │
                       ▼          ▼          ▼
                    ┌─────────────────────────────────┐
                    │   MUX DE LECTURA                │
                    │   (sec. 5 del bus_driver)       │
                    └─────────────┬───────────────────┘
                                  │
                                  ▼
                           core_rdata_o [31:0]
```

---

## 5. Tabla de latencias

| Operación                        | Latencia (ciclos) | Razón                                       |
|----------------------------------|:-----------------:|---------------------------------------------|
| Escritura a RAM                  | 1                 | BMG escribe en flanco siguiente             |
| Escritura a LED                  | 1                 | Flip-flops internos del `led_peripheral`    |
| Escritura a UART                 | 1                 | Flip-flops internos del `uart_peripheral`   |
| Lectura de RAM                   | 1                 | BMG configurado sin output register         |
| Lectura de SW/BTN                | 1                 | Alineación forzada por `sw_data_q`          |
| Lectura de UART                  | 1                 | Alineación forzada por `uart_data_q`        |
| Lectura de dirección no mapeada  | 1                 | Devuelve `0x00000000` con latencia uniforme |

> La uniformidad de latencia es clave para que `riscv_core.sv` (que ya
> implementa `mem_ready` con un flip-flop de 1 ciclo) funcione
> correctamente con todo el sistema de memoria.

---

## 6. Cobertura del instructivo

| Requisito (sección del PDF)                            | Estado |
|--------------------------------------------------------|--------|
| Mapa de memoria de la Figura 4 implementado            | ✅     |
| RAM de 100 KiB en `0x40000`–`0x7FFFF`                  | ✅     |
| Registros de periféricos en direcciones especificadas  | ✅     |
| RAM implementada con IP-Core (BMG)                     | ✅     |
| Bus independiente de instrucciones y datos             | ✅     |
| Bloque multiplexor según mapa de memoria               | ✅     |
| Documentación de tablas, diagramas                     | ✅     |
