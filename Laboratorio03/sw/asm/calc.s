# =============================================================================
# Archivo      : sw/asm/calc.s
# Autor        : WallyCR
# Fecha        : 21 de abril de 2026
# Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
# Lab 2        : Microcontrolador - Aplicación calculadora UART (RV32I puro)
#
# Spec (Lab 2 sección 4.4.1):
#   1. Al inicio: indicar por LEDs que el RISC-V está listo
#   2. Esperar paquete UART: N1 (max 4 dígitos) + (+/-) + N2 (max 4 dígitos) + ENTER
#   3. Hacer eco de los caracteres recibidos
#   4. Responder con el resultado
#   5. Correr indefinidamente
#
# Mapa de memoria:
#   0x02004  GPIO_LED  (RW)
#   0x02010  UART_CTRL ([0]=send, [1]=new_rx)
#   0x02018  UART_TX
#   0x0201C  UART_RX
#   0x40000-0x80000  RAM (stack en 0x58FFC)
# =============================================================================

    .section .text
    .globl  _start

# Constantes
    .equ GPIO_LED,   0x02004
    .equ UART_CTRL,  0x02010
    .equ UART_TX,    0x02018
    .equ UART_RX,    0x0201C

    .equ CHAR_PLUS,  0x2B
    .equ CHAR_MINUS, 0x2D
    .equ CHAR_CR,    0x0D
    .equ CHAR_LF,    0x0A
    .equ CHAR_0,     0x30
    .equ CHAR_9,     0x39
    .equ CHAR_EQ,    0x3D
    .equ CHAR_NEG,   0x2D

    .equ LED_READY,  0x001
    .equ LED_BUSY,   0x002

# =============================================================================
# _start: punto de entrada (PC=0x0 al reset)
# =============================================================================
_start:
    li      sp, 0x58FFC

    # Pointers a periféricos en s0..s3 (callee-saved)
    li      s0, GPIO_LED
    li      s1, UART_CTRL
    li      s2, UART_TX
    li      s3, UART_RX

    # Indicar "ready" por LEDs
    li      t0, LED_READY
    sw      t0, 0(s0)

# =============================================================================
# main_loop
#   s4 = N1, s5 = N2, s6 = operador
# =============================================================================
main_loop:
    li      t0, LED_READY
    sw      t0, 0(s0)

    # ---- Leer N1 (hasta 4 dígitos, termina con + o -) ----
    li      s4, 0
    li      a1, 4
read_n1:
    jal     ra, uart_getc
    jal     ra, uart_putc      # eco

    li      t0, CHAR_PLUS
    beq     a0, t0, n1_done
    li      t0, CHAR_MINUS
    beq     a0, t0, n1_done

    # ¿Es dígito 0..9?
    li      t0, CHAR_0
    blt     a0, t0, read_n1
    li      t0, CHAR_9
    bgt     a0, t0, read_n1

    # Acumular: s4 = s4 * 10 + (a0 - '0')
    beq     a1, x0, read_n1
    addi    a1, a1, -1
    slli    t1, s4, 3          # s4 * 8
    slli    t2, s4, 1          # s4 * 2
    add     s4, t1, t2         # s4 * 10
    addi    t0, a0, -CHAR_0
    add     s4, s4, t0
    j       read_n1

n1_done:
    mv      s6, a0             # guardar operador

    li      t0, LED_BUSY
    sw      t0, 0(s0)

    # ---- Leer N2 (hasta 4 dígitos, termina con CR o LF) ----
    li      s5, 0
    li      a1, 4
read_n2:
    jal     ra, uart_getc
    jal     ra, uart_putc

    li      t0, CHAR_CR
    beq     a0, t0, n2_done
    li      t0, CHAR_LF
    beq     a0, t0, n2_done

    li      t0, CHAR_0
    blt     a0, t0, read_n2
    li      t0, CHAR_9
    bgt     a0, t0, read_n2

    beq     a1, x0, read_n2
    addi    a1, a1, -1
    slli    t1, s5, 3
    slli    t2, s5, 1
    add     s5, t1, t2
    addi    t0, a0, -CHAR_0
    add     s5, s5, t0
    j       read_n2

n2_done:
    # ---- Calcular ----
    li      t0, CHAR_PLUS
    beq     s6, t0, do_add
    sub     s4, s4, s5
    j       respond
do_add:
    add     s4, s4, s5

respond:
    # ---- Imprimir "\r\n=" ----
    li      a0, CHAR_CR
    jal     ra, uart_putc
    li      a0, CHAR_LF
    jal     ra, uart_putc
    li      a0, CHAR_EQ
    jal     ra, uart_putc

    # ---- Imprimir resultado ----
    mv      a0, s4
    jal     ra, print_int

    # ---- "\r\n" final ----
    li      a0, CHAR_CR
    jal     ra, uart_putc
    li      a0, CHAR_LF
    jal     ra, uart_putc

    j       main_loop

# =============================================================================
# uart_putc: envía a0 (byte). Modifica t0.
# =============================================================================
uart_putc:
uart_putc_wait1:
    lw      t0, 0(s1)
    andi    t0, t0, 0x1
    bne     t0, x0, uart_putc_wait1

    sw      a0, 0(s2)
    li      t0, 0x1
    sw      t0, 0(s1)

uart_putc_wait2:
    lw      t0, 0(s1)
    andi    t0, t0, 0x1
    bne     t0, x0, uart_putc_wait2

    jalr    x0, 0(ra)

# =============================================================================
# uart_getc: espera 1 byte, devuelve en a0. Modifica t0.
# =============================================================================
uart_getc:
uart_getc_wait:
    lw      t0, 0(s1)
    andi    t0, t0, 0x2
    beq     t0, x0, uart_getc_wait

    lw      a0, 0(s3)
    andi    a0, a0, 0xFF
    sw      x0, 0(s1)          # limpiar new_rx

    # Filtrar bytes basura: solo dígitos, +, -, CR, LF
    li      t0, 0x0D           # CR
    beq     a0, t0, uart_getc_ok
    li      t0, 0x0A           # LF
    beq     a0, t0, uart_getc_ok
    li      t0, 0x2B           # '+'
    beq     a0, t0, uart_getc_ok
    li      t0, 0x2D           # '-'
    beq     a0, t0, uart_getc_ok
    li      t0, 0x30           # '0'
    blt     a0, t0, uart_getc_wait
    li      t0, 0x39           # '9'
    bgt     a0, t0, uart_getc_wait
uart_getc_ok:
    jalr    x0, 0(ra)
# =============================================================================
# print_int: imprime a0 (con signo) en decimal. NO usa el stack.
#   Usa t6 para guardar ra (evitando el bug del buffer en RAM).
#   Itera por las potencias de 10 (10000, 1000, 100, 10, 1).
#   Suprime ceros a la izquierda. Maneja 0 y negativos.
#   Modifica: a0, t1, t2, t3, t4, t5, t6, ra
# =============================================================================
print_int:
    mv      t6, ra              # guardar ra del caller en t6 (callee-saved-like)

    # ---- Manejar negativo ----
    bge     a0, x0, pi_pos
    mv      t4, a0
    li      a0, CHAR_NEG
    jal     ra, uart_putc
    sub     a0, x0, t4          # a0 = abs(a0)
pi_pos:

    # ---- Caso especial: 0 ----
    bne     a0, x0, pi_nonzero
    li      a0, CHAR_0
    jal     ra, uart_putc
    j       pi_return
pi_nonzero:

    mv      t4, a0              # t4 = número restante
    li      t2, 0               # t2 = flag "ya emití un dígito no-cero"

    # ---- Decenas de millar (10000) ----
    li      t1, 10000
    li      t3, 0
pi_d10k:
    blt     t4, t1, pi_d10k_end
    sub     t4, t4, t1
    addi    t3, t3, 1
    j       pi_d10k
pi_d10k_end:
    beq     t3, x0, pi_d1k         # si dígito = 0 y flag=0, saltar
    li      t2, 1
    addi    a0, t3, CHAR_0
    jal     ra, uart_putc

    # ---- Miles (1000) ----
pi_d1k:
    li      t1, 1000
    li      t3, 0
pi_d1k_loop:
    blt     t4, t1, pi_d1k_end
    sub     t4, t4, t1
    addi    t3, t3, 1
    j       pi_d1k_loop
pi_d1k_end:
    bne     t3, x0, pi_d1k_print
    beq     t2, x0, pi_d100        # dígito 0 y aún no hubo no-cero -> saltar
pi_d1k_print:
    li      t2, 1
    addi    a0, t3, CHAR_0
    jal     ra, uart_putc

    # ---- Centenas (100) ----
pi_d100:
    li      t1, 100
    li      t3, 0
pi_d100_loop:
    blt     t4, t1, pi_d100_end
    sub     t4, t4, t1
    addi    t3, t3, 1
    j       pi_d100_loop
pi_d100_end:
    bne     t3, x0, pi_d100_print
    beq     t2, x0, pi_d10
pi_d100_print:
    li      t2, 1
    addi    a0, t3, CHAR_0
    jal     ra, uart_putc

    # ---- Decenas (10) ----
pi_d10:
    li      t1, 10
    li      t3, 0
pi_d10_loop:
    blt     t4, t1, pi_d10_end
    sub     t4, t4, t1
    addi    t3, t3, 1
    j       pi_d10_loop
pi_d10_end:
    bne     t3, x0, pi_d10_print
    beq     t2, x0, pi_d1
pi_d10_print:
    addi    a0, t3, CHAR_0
    jal     ra, uart_putc

    # ---- Unidades (siempre se imprime) ----
pi_d1:
    addi    a0, t4, CHAR_0
    jal     ra, uart_putc

pi_return:
    mv      ra, t6
    jalr    x0, 0(ra)
    
