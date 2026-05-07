# =============================================================================
# Archivo      : sw/asm/blink.s
# Proposito    : SMOKE TEST del SoC. NO usa stack, NO usa UART, NO usa RAM.
#                Solo hace:
#                  1. Cargar 0xFFF en GPIO_LED -> enciende LED0..LED11.
#                  2. Loop infinito.
#
#                Si despues de programar la FPGA con este .coe los LEDs 0..11
#                se encienden (12 LEDs azules de la fila inferior), el SoC
#                funciona y el problema esta en calc.s o su interaccion con
#                la UART/RAM. Si NO se encienden, el SoC esta roto y hay que
#                arreglarlo antes de pelear con calc.s.
# =============================================================================
    .section .text
    .globl  _start

_start:
    # Cargar direccion del registro LED (0x02004) en s0.
    # 'li' se expande a 'lui s0, 0x2 ; addi s0, s0, 4'.
    li      s0, 0x02004

    # Cargar 0xFFF (los 12 bits bajos en uno) en t0.
    li      t0, 0xFFF

    # Escribir el patron al registro de LEDs.
    sw      t0, 0(s0)

# Loop infinito. 'j .' = jal x0, . (salta a si mismo).
hang:
    j       hang
