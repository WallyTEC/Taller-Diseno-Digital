# =============================================================================
# Archivo      : sw/asm/hello_blink.s
# Autor        : WallyCR
# Fecha        : 20 de abril de 2026
# Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
# Descripción  : Programa de prueba mínimo para validar el SoC.
#
#                Funcionalidad:
#                  1. Manda "READY\r\n" por UART al inicio.
#                  2. Loop principal:
#                     - Lee switches y los muestra en LEDs.
#                     - Si llega un byte por UART, lo envía de vuelta
#                       (echo) y alterna un LED extra.
#
#                Esto valida:
#                  - Que la ROM se cargó bien (PC arranca en 0x0)
#                  - Que la RAM funciona (stack al inicio)
#                  - Que el UART transmite (READY)
#                  - Que el UART recibe (echo)
#                  - Que GPIO_SW lee switches
#                  - Que GPIO_LED escribe LEDs
#
# Convenciones:
#   x10 = a0  : argumentos / temporales
#   x11 = a1
#   x12 = a2
#   x5..x7    : temporales libres
#
# Mapa de memoria (recordatorio):
#   0x02000   GPIO_SW  (RO)
#   0x02004   GPIO_LED (RW)
#   0x02010   UART_CTRL [0]=send, [1]=new_rx
#   0x02018   UART_TX (Data 1)
#   0x0201C   UART_RX (Data 2)
#
# Stack: tope a 0x58FFC (último word físico de la RAM 100 KiB)
# =============================================================================

    .section .text
    .globl  _start

# =============================================================================
# _start: punto de entrada (ejecutado en el reset, PC=0x0)
# =============================================================================
_start:
    # --- Setup inicial ---
    li      sp, 0x58FFC          # stack pointer al tope de la RAM (alineado)

    # Direcciones base como constantes en registros
    li      s0, 0x02000          # GPIO_SW base
    li      s1, 0x02004          # GPIO_LED base
    li      s2, 0x02010          # UART_CTRL
    li      s3, 0x02018          # UART_TX
    li      s4, 0x0201C          # UART_RX

    # --- LEDs apagados al inicio ---
    sw      x0, 0(s1)

    # --- Imprimir "READY\r\n" por UART ---
    la      a0, msg_ready
    jal     ra, uart_puts

# =============================================================================
# main_loop: loop principal infinito
#   - Refleja switches en LEDs (excepto el LED 11, que es el toggle UART).
#   - Si hay byte nuevo en UART, lo manda de vuelta (echo) y toggle LED 11.
# =============================================================================
main_loop:
    # 1. Leer switches y volcar a LEDs (mantenemos LED 11 con su valor actual)
    lw      t0, 0(s0)            # t0 = palabra de SW/BTN
    andi    t0, t0, 0x7FF        # quedarnos con bits [10:0] (los SW0..SW10)
    lw      t1, 0(s1)            # t1 = LEDs actuales
    li      t2, 0x800
    and     t1, t1, t2           # preservar sólo bit 11 (LED de actividad UART)
    or      t0, t0, t1           # combinar
    sw      t0, 0(s1)            # escribir a LEDs

    # 2. Chequear si llegó un byte por UART
    lw      t2, 0(s2)            # t2 = CTRL
    andi    t3, t2, 0x2          # bit 1 = new_rx
    beq     t3, x0, main_loop    # si no, seguir

    # 3. Tenemos un byte. Leerlo.
    lw      a0, 0(s4)            # a0 = byte RX (en bits [7:0])
    andi    a0, a0, 0xFF

    # 4. Limpiar new_rx escribiendo 0 al CTRL (también limpia send que ya está bajo)
    sw      x0, 0(s2)

    # 5. Toggle LED 11 (bit 11 de los LEDs)
    lw      t1, 0(s1)
    li      t2, 0x800            # máscara del bit 11
    xor     t1, t1, t2
    sw      t1, 0(s1)

    # 6. Echo: mandar el byte de vuelta
    jal     ra, uart_putc

    j       main_loop

# =============================================================================
# uart_putc: envía el byte en a0 por UART (bloqueante).
#   Modifica: t0
# =============================================================================
uart_putc:
    # Esperar a que send=0 (TX libre) antes de cargar
uart_putc_wait:
    lw      t0, 0(s2)            # CTRL
    andi    t0, t0, 0x1
    bne     t0, x0, uart_putc_wait

    sw      a0, 0(s3)            # cargar byte en TX (Data 1)
    li      t0, 0x1
    sw      t0, 0(s2)            # CTRL.send = 1

    # Esperar a que HW baje send (TX arrancó/terminó)
uart_putc_done:
    lw      t0, 0(s2)
    andi    t0, t0, 0x1
    bne     t0, x0, uart_putc_done

    jalr    x0, 0(ra)

# =============================================================================
# uart_puts: envía la cadena terminada en NUL apuntada por a0.
#   Modifica: a0, t4, ra (pero salva ra en stack)
# =============================================================================
uart_puts:
    addi    sp, sp, -8
    sw      ra, 0(sp)
    sw      s5, 4(sp)
    addi    s5, a0, 0            # s5 = puntero a la cadena

uart_puts_loop:
    lbu     a0, 0(s5)
    beq     a0, x0, uart_puts_done
    jal     ra, uart_putc
    addi    s5, s5, 1
    j       uart_puts_loop

uart_puts_done:
    lw      ra, 0(sp)
    lw      s5, 4(sp)
    addi    sp, sp, 8
    jalr    x0, 0(ra)

# =============================================================================
# Sección de datos (constantes inicializadas) — quedan en ROM
# =============================================================================
    .section .rodata

msg_ready:
    .ascii "READY\r\n"
    .byte  0
