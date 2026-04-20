# Microcontrolador RISC-V RV32I con periféricos UART/GPIO

**Curso:** EL3313 Taller de Diseño Digital — I Semestre 2026
**Institución:** Escuela de Ingeniería Electrónica, Tecnológico de Costa Rica
**Profesor:** Kaled Alfaro Badilla, M.Sc.
**Autor(es):** [tu nombre completo] — carnet [número]
**Tarjeta FPGA:** Digilent Nexys4 DDR (Artix-7 XC7A100T-1CSG324C)
**Herramientas:** Xilinx Vivado 2023.2, SystemVerilog, Python 3

---

## 1. Descripción del proyecto

Sistema empotrado basado en un núcleo RISC-V RV32I (PicoRV32) implementado sobre FPGA,
comunicado con una computadora anfitriona por UART. El sistema ejecuta una **calculadora de
enteros** (suma y resta de números de hasta 4 dígitos) desde un programa en ensamblador
almacenado en ROM interna.

La arquitectura se basa en un bus **AXI4-Lite** que interconecta el núcleo (master) con
memoria RAM, memoria ROM y tres periféricos mapeados en memoria (UART, LEDs,
Switches/Botones).

## 2. Arquitectura

![Diagrama de bloques](docs/figures/block_diagram.svg)

### 2.1 Mapa de memoria

| Rango             | Tamaño   | Bloque            | Descripción                        |
|-------------------|----------|-------------------|------------------------------------|
| `0x00000–0x00FFF` | 4 KiB    | ROM               | Programa (512 palabras de 32 bits) |
| `0x02000`         | 4 B      | GPIO SW/BTN       | Registro de datos (RO)             |
| `0x02004`         | 4 B      | GPIO LEDs         | Registro de datos (RW)             |
| `0x02010`         | 4 B      | UART Control      | `[0]=send`, `[1]=new_rx`           |
| `0x02018`         | 4 B      | UART Data TX      | Dato a enviar                      |
| `0x0201C`         | 4 B      | UART Data RX      | Último dato recibido               |
| `0x40000–0x7FFFF` | 256 KiB  | RAM (stack/heap)  | Datos                              |

### 2.2 Convención de señales (AXI4-Lite)

Todos los periféricos exponen una interfaz AXI4-Lite Slave estándar:
`s_axi_awaddr`, `s_axi_awvalid`, `s_axi_awready`, `s_axi_wdata`, `s_axi_wstrb`,
`s_axi_wvalid`, `s_axi_wready`, `s_axi_bresp`, `s_axi_bvalid`, `s_axi_bready`,
`s_axi_araddr`, `s_axi_arvalid`, `s_axi_arready`, `s_axi_rdata`, `s_axi_rresp`,
`s_axi_rvalid`, `s_axi_rready`. Reset activo-bajo (`s_axi_aresetn`).

## 3. Estructura del repositorio

```
rtl/            Código SystemVerilog sintetizable
sim/            Testbenches (self-checking)
sw/             Software en ensamblador + herramientas Python
ip/             Scripts TCL para regenerar los IP cores
scripts/        Scripts TCL para crear el proyecto Vivado
constraints/    Archivo de restricciones (.xdc)
docs/           Informe técnico, diagramas, figuras
tests/          Casos de prueba para software
```

## 4. Cómo reproducir el proyecto

### 4.1 Requisitos
- Vivado 2023.2 o superior
- Python 3.9+ (para el ensamblador `rv32i_asm.py`)
- Tarjeta Nexys4 DDR conectada por USB

### 4.2 Generar el binario del programa

```bash
cd sw/
python3 tools/rv32i_asm.py asm/calculator.s -o build/main.coe
```

### 4.3 Crear el proyecto Vivado desde cero

```bash
cd scripts/
vivado -mode batch -source create_project.tcl
```

El script genera `build/lab2.xpr`, instancia los IP cores (`clk_wiz_main`,
`rom_program`, `data_ram`) y agrega todos los fuentes RTL y constraints.

### 4.4 Sintetizar, implementar y programar

```bash
vivado -mode batch -source scripts/build.tcl
vivado -mode batch -source scripts/program_fpga.tcl
```

### 4.5 Uso

Abrir un terminal serial (p. ej. `picocom /dev/ttyUSB1 -b 9600`) y enviar:

```
1234+5678<ENTER>
```

El sistema hará eco de los caracteres y responderá con el resultado.

## 5. Verificación

Cada módulo tiene un testbench auto-verificable en `sim/`. Para correrlos:

```bash
cd sim/
vivado -mode batch -source run_all_tests.tcl
```

Resultados esperados: todos los `assert`/`$display` deben reportar `PASS`.

## 6. Resultados de implementación

| Métrica           | Valor        |
|-------------------|--------------|
| Frecuencia        | 50 MHz       |
| Slack WNS         | [llenar]     |
| LUTs usadas       | [llenar]     |
| FFs usados        | [llenar]     |
| BRAMs usadas      | [llenar]     |
| Potencia total    | [llenar]     |

## 7. Créditos y licencia

- **PicoRV32** por Claire Xenia Wolf (YosysHQ). Licencia ISC.
  Repositorio: https://github.com/YosysHQ/picorv32
- Todo el código propio de este repositorio se distribuye bajo licencia MIT
  (ver `LICENSE`).
- Asistencia de IA en el desarrollo: ver `AI_USAGE.md`.

## 8. Referencias

1. Patterson & Hennessy. *Computer Organization and Design RISC-V Edition*. Morgan Kaufmann, 2017.
2. ARM. *AMBA AXI and ACE Protocol Specification*. IHI 0022H, 2021.
3. Digilent. *Nexys 4 DDR FPGA Board Reference Manual*, 2016.
4. Xilinx. *AXI4-Lite Slave Interface — Product Guide PG059*, 2022.
5. Instructivo de laboratorio 2, EL3313, I-2026, TEC.
