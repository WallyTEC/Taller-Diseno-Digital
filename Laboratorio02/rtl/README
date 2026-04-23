## Carpetas

### `bus/` — Bus AXI-Lite

Implementación del bus interno que conecta el core con todos los slaves del sistema. Sigue el estándar AXI4-Lite con 5 canales (AW, W, B, AR, R).

| Archivo | Descripción |
|---|---|
| `axil_defs.svh` | Header global con anchos del bus, mapa de memoria (bases y máscaras), códigos de respuesta AXI e índices de slaves. Marcado como **Global Include** en Vivado. |
| `axil_interconnect.sv` | Interconnect 1 master → 5 slaves. Decodificación combinacional de direcciones, FSMs independientes para read/write, generación de DECERR cuando la dirección no matchea. |

### `core/` — Procesador RISC-V

| Archivo | Descripción |
|---|---|
| `picorv32.v` | Core PicoRV32 (third-party, [YosysHQ/picorv32](https://github.com/YosysHQ/picorv32)). Variante `picorv32_axi` con interfaz AXI-Lite master. Configurado para RV32I sin extensiones (sin M, sin C). |

### `memory/` — Memorias

| Archivo | Descripción |
|---|---|
| `rom_axil.sv` | ROM inferrable con `$readmemh`. Versión alternativa para simulación pura (no usada en síntesis). |
| `rom_axil_with_ip.sv` | **Wrapper AXI-Lite del IP `rom_program`** (Block Memory Generator de Vivado). 512 palabras × 32 bits, inicializado desde `main.coe`. Read-only: las escrituras devuelven SLVERR. |
| `ram_axil.sv` | RAM inferrable. Versión alternativa para simulación. |
| `ram_axil_with_ip.sv` | **Wrapper AXI-Lite del IP `data_ram`** (Block Memory Generator). 25600 palabras × 32 bits = 100 KiB, con byte write enable para soportar `sb`/`sh`. |

### `peripherals/` — Periféricos

| Archivo | Descripción |
|---|---|
| `gpio_leds_axil.sv` | Slave AXI-Lite para los 12 LEDs controlados por programa. Mapeado a `0x02004`. |
| `gpio_sw_btn_axil.sv` | Slave AXI-Lite RO para 16 switches + 4 botones. Incluye sincronizador 2-FF y debouncer de 10 ms. Mapeado a `0x02000`. |
| `uart/` | Subcarpeta con la implementación completa del UART (ver abajo). |

#### `peripherals/uart/`

| Archivo | Descripción |
|---|---|
| `uart_axil.sv` | Wrapper AXI-Lite del UART. Expone CTRL (`0x02010`), TX_DATA (`0x02018`) y RX_DATA (`0x0201C`). Maneja registros `send` y `new_rx` con la lógica de handshake del lab. |
| `uart_baud_gen.sv` | Generador de tick para TX. Tick cada 5208 ciclos a 50 MHz = 9600 baud. |
| `uart_tx.sv` | FSM transmisor 8N1. Estados: IDLE → START → DATA (×8) → STOP. |
| `uart_rx.sv` | FSM receptor 8N1 autosuficiente. Cuenta ciclos directamente (no usa tick externo) para evitar drift acumulado. Muestrea en el centro de cada bit. |

### `util/` — Utilitarios

| Archivo | Descripción |
|---|---|
| `synchronizer.sv` | Sincronizador de 2-FF parametrizable con atributo `ASYNC_REG = "TRUE"` para optimización de Vivado. Usado para entradas asíncronas (UART RX, switches, botones). |
| `debouncer.sv` | Anti-rebote de 10 ms para botones mecánicos. Cuenta ciclos a 50 MHz. |
| `reset_sync.sv` | Reset síncrono con asserción asíncrona y deasserción síncrona. 3 etapas de FF para minimizar metaestabilidad. |

### `top.sv`

Top-level del SoC. Instancia y conecta:

- PLL (clk_wiz_main): 100 MHz → 50 MHz
- `reset_sync`: maneja BTNC + locked del PLL
- `picorv32_axi` con `STACKADDR=0x58FFC` y `PROGADDR_RESET=0x0`
- `axil_interconnect` (1 master → 5 slaves)
- 5 slaves: ROM, RAM, GPIO_SW, GPIO_LED, UART
- LEDs de debug en los 4 bits altos:
  - LED 12: `pll_locked`
  - LED 13: `rst_n`
  - LED 14: `core_trap`
  - LED 15: heartbeat (~1.5 Hz)

## Convenciones de código

- **SystemVerilog moderno**: `always_comb`, `always_ff`, tipo `logic`
- **Naming**: `snake_case` para señales, `MAYUSCULAS` para parámetros
- **Sufijos de I/O**: `_i` para entradas, `_o` para salidas (señales no-AXI)
- **Prefijos AXI**: `s_axi_` para slaves, `m_axi_` para masters
- **Reset**: activo-bajo, señal `s_axi_aresetn`
- **Diseño jerárquico**: cada bloque en su propio archivo con un módulo
- **Síntesis limpia**: sin latches inferidos, sin flip-flops no intencionales

## Mapa de memoria

| Dirección | Slave | Tipo | Tamaño |
|---|---|---|---|
| `0x00000 - 0x00FFF` | ROM | RO | 4 KiB |
| `0x02000` | GPIO_SW_BTN | RO | 1 word |
| `0x02004` | GPIO_LED | RW | 1 word |
| `0x02010` | UART_CTRL | RW | 1 word |
| `0x02018` | UART_TX | RW | 1 word |
| `0x0201C` | UART_RX | RO | 1 word |
| `0x40000 - 0x7FFFF` | RAM | RW | 256 KiB |

Las direcciones siguen el mapa de memoria definido en el instructivo del Lab 2.

## Dependencias

- **Vivado 2024.1** o superior
- IPs requeridos (creados desde la GUI o con scripts en `../ip/`):
  - `clk_wiz_main` (Clocking Wizard, MMCM)
  - `rom_program` (Block Memory Generator, Single Port ROM, init desde `.coe`)
  - `data_ram` (Block Memory Generator, Single Port RAM, byte write enable)

## Testbenches

Los testbenches asociados están en `../sim/`:

- `tb_axil_interconnect.sv` — 36 checks (ruteo + DECERR)
- `tb_gpio_leds_axil.sv` — 7 checks
- `tb_gpio_sw_btn_axil.sv` — 4 checks (con debounce acelerado)
- `tb_uart_axil.sv` — 7 checks (TX, RX, send auto-clear, new_rx)
- `tb_uart_loopback.sv` — 8 bytes round-trip

Todos los testbenches son self-checking con un contador global de errores y una función `check(cond, msg)` para reportar resultados.
