# Microcontrolador RISC-V RV32I con periféricos UART/GPIO

**Curso:** EL3313 Taller de Diseño Digital — I Semestre 2026
**Institución:** Escuela de Ingeniería Electrónica, Tecnológico de Costa Rica
**Profesor:** Kaled Alfaro Badilla, M.Sc.
**Autores:** Walter-Allan-Alexander-Esteban
**Tarjeta FPGA:** Digilent Nexys4 DDR (Artix-7 XC7A100T-1CSG324C)
**Herramientas:** Xilinx Vivado 2024.1, SystemVerilog, Python 3

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

## 4. Créditos y licencia

- **PicoRV32** por Claire Xenia Wolf (YosysHQ). Licencia ISC.
  Repositorio: https://github.com/YosysHQ/picorv32
- Todo el código propio de este repositorio se distribuye bajo licencia MIT
  (ver `LICENSE`).
- Asistencia de IA en el desarrollo: ver `AI_USAGE.md`.

## 5. Referencias

1. Patterson & Hennessy. *Computer Organization and Design RISC-V Edition*. Morgan Kaufmann, 2017.
2. ARM. *AMBA AXI and ACE Protocol Specification*. IHI 0022H, 2021.
3. Digilent. *Nexys 4 DDR FPGA Board Reference Manual*, 2016.
4. Xilinx. *AXI4-Lite Slave Interface — Product Guide PG059*, 2022.
5. Instructivo de laboratorio 2, EL3313, I-2026, TEC.
