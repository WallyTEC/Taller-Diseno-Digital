// =============================================================================
// File        : axil_defs.svh
// Project     : EL3313 - Taller de Diseno Digital - Lab 2
// Institution : Tecnologico de Costa Rica
// Author      : [TU NOMBRE COMPLETO] - Carnet [NUMERO]
// Date        : 2026-04-20
// -----------------------------------------------------------------------------
// Description :
//   Definiciones globales del bus AXI4-Lite del SoC:
//     * Anchos de datos y direcciones
//     * Mapa de memoria (bases y mascaras de cada slave)
//     * Offsets internos del slave UART
//     * Codigos de respuesta AXI4-Lite (OKAY / SLVERR / DECERR)
//
//   Este archivo debe ser incluido en todo modulo que necesite decodificar
//   direcciones o interpretar respuestas del bus.
//
// AI assistance : Estructura inicial y mascaras generadas con asistencia de
//                 Claude (Anthropic). Direcciones base tomadas del instructivo
//                 EL3313 Lab 2 I-2026. Revisado y ajustado por el autor.
// =============================================================================

`ifndef AXIL_DEFS_SVH
`define AXIL_DEFS_SVH

// -----------------------------------------------------------------------------
// Anchos del bus AXI4-Lite
// -----------------------------------------------------------------------------
// El mapa de memoria llega hasta 0x7FFFF (RAM top), por lo que 20 bits de
// direccion son suficientes. Si en el futuro se agregan perifericos mas
// arriba de 0x80000, aumentar ADDR_WIDTH.
// -----------------------------------------------------------------------------
localparam int unsigned AXIL_DATA_WIDTH = 32;
localparam int unsigned AXIL_ADDR_WIDTH = 20;
localparam int unsigned AXIL_STRB_WIDTH = AXIL_DATA_WIDTH / 8;   // 4 bytes

// -----------------------------------------------------------------------------
// Codigos de respuesta AXI4-Lite (B/R channels)
//   OKAY   : transaccion exitosa
//   EXOKAY : reservado en AXI-Lite (no se usa)
//   SLVERR : el slave reconocio la direccion pero fallo (p.ej. write a ROM)
//   DECERR : ningun slave matcheo la direccion (error del decoder)
// -----------------------------------------------------------------------------
localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
localparam logic [1:0] AXI_RESP_EXOKAY = 2'b01;
localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;
localparam logic [1:0] AXI_RESP_DECERR = 2'b11;

// -----------------------------------------------------------------------------
// Mapa de memoria del SoC
// -----------------------------------------------------------------------------
//   Base       End          Tamano    Bloque
//   0x00000    0x00FFF      4 KiB     ROM (programa)
//   0x02000    0x02003      4 B       GPIO Switches/Botones (RO)
//   0x02004    0x02007      4 B       GPIO LEDs (RW)
//   0x02010    0x0201F      16 B      UART (3 registros mapeados)
//   0x40000    0x7FFFF      256 KiB   RAM (datos, stack y heap)
//
// Para cada slave se define una BASE y una MASK. Un slave se selecciona
// cuando se cumple:
//     (araddr & MASK) == BASE   (para lecturas)
//     (awaddr & MASK) == BASE   (para escrituras)
// -----------------------------------------------------------------------------

// ---- ROM: 0x00000 - 0x00FFF (12 bits internos, 4 KiB) -----------------------
localparam logic [AXIL_ADDR_WIDTH-1:0] ROM_BASE = 20'h00000;
localparam logic [AXIL_ADDR_WIDTH-1:0] ROM_MASK = 20'hFF000;

// ---- GPIO Switches/Botones: solo 0x02000 (1 palabra) ------------------------
localparam logic [AXIL_ADDR_WIDTH-1:0] GPIO_SW_BASE = 20'h02000;
localparam logic [AXIL_ADDR_WIDTH-1:0] GPIO_SW_MASK = 20'hFFFFC;

// ---- GPIO LEDs: solo 0x02004 (1 palabra) ------------------------------------
localparam logic [AXIL_ADDR_WIDTH-1:0] GPIO_LED_BASE = 20'h02004;
localparam logic [AXIL_ADDR_WIDTH-1:0] GPIO_LED_MASK = 20'hFFFFC;

// ---- UART: 0x02010 - 0x0201F (16 bytes, cubre CTRL/TX/RX) -------------------
localparam logic [AXIL_ADDR_WIDTH-1:0] UART_BASE = 20'h02010;
localparam logic [AXIL_ADDR_WIDTH-1:0] UART_MASK = 20'hFFFF0;

// ---- RAM: 0x40000 - 0x7FFFF (256 KiB) ---------------------------------------
//   La mascara 0xC0000 matchea bits [19:18] == 2'b01:
//     0x40000 & 0xC0000 = 0x40000 OK
//     0x7FFFF & 0xC0000 = 0x40000 OK
//     0x80000 & 0xC0000 = 0x80000 NO MATCH (correcto, fuera de rango)
// -----------------------------------------------------------------------------
localparam logic [AXIL_ADDR_WIDTH-1:0] RAM_BASE = 20'h40000;
localparam logic [AXIL_ADDR_WIDTH-1:0] RAM_MASK = 20'hC0000;

// -----------------------------------------------------------------------------
// Offsets internos del slave UART
//   El decoder del interconnect entrega al UART los 4 bits bajos de la
//   direccion (addr[3:0]). El slave UART usa estos offsets para seleccionar
//   su registro interno.
// -----------------------------------------------------------------------------
localparam logic [3:0] UART_OFFSET_CTRL = 4'h0;   // 0x02010: registro control
localparam logic [3:0] UART_OFFSET_TX   = 4'h8;   // 0x02018: dato a transmitir
localparam logic [3:0] UART_OFFSET_RX   = 4'hC;   // 0x0201C: dato recibido

// -----------------------------------------------------------------------------
// Bits del registro de control del UART (offset 0x00)
// -----------------------------------------------------------------------------
localparam int UART_CTRL_BIT_SEND   = 0;          // 1 = disparar TX; se auto-limpia al terminar
localparam int UART_CTRL_BIT_NEW_RX = 1;          // 1 = hay byte nuevo en RX; se limpia al leer el dato

// -----------------------------------------------------------------------------
// Numero de slaves (usado por el interconnect para dimensionar arrays)
// -----------------------------------------------------------------------------
localparam int unsigned NUM_SLAVES = 5;

// Indices de cada slave en los arrays del interconnect
localparam int SLAVE_IDX_ROM      = 0;
localparam int SLAVE_IDX_RAM      = 1;
localparam int SLAVE_IDX_GPIO_SW  = 2;
localparam int SLAVE_IDX_GPIO_LED = 3;
localparam int SLAVE_IDX_UART     = 4;

`endif // AXIL_DEFS_SVH
