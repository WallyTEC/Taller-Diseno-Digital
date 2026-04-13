# =============================================================================
# main.s — Calculadora RV32I pura (sin extensión M)
# -----------------------------------------------------------------------------
# Mapa de memoria:
#   0x02004 -> LEDs
#   0x02010 -> UART Control (bit0=send, bit1=new_rx)
#   0x02018 -> UART TX
#   0x0201C -> UART RX
# =============================================================================

.section .text
.globl _start

_start:
    # Inicializar stack pointer
    li   sp, 0x0007FFFC

    # Encender todos los LEDs — sistema listo
    li   t0, 0x02004
    li   t1, 0x0000FFFF
    sw   t1, 0(t0)

# =============================================================================
# Loop principal
# =============================================================================
main_loop:
    li   s0, 0          # primer número
    li   s1, 0          # segundo número
    li   s2, 0          # operador

# -----------------------------------------------------------------------------
# Leer primer número — termina al recibir + o -
# -----------------------------------------------------------------------------
read_num1:
    call uart_getchar   # a0 = carácter
    call uart_putchar   # echo

    # ¿Dígito?
    li   t0, 48         # '0'
    blt  a0, t0, read_num1
    li   t0, 57         # '9'
    ble  a0, t0, digit1

    # ¿Operador?
    li   t0, 43         # '+'
    beq  a0, t0, got_op
    li   t0, 45         # '-'
    beq  a0, t0, got_op
    j    read_num1

digit1:
    # s0 = s0 * 10 + (a0 - '0')
    # s0 * 10 = (s0 << 3) + (s0 << 1)
    slli t0, s0, 3      # s0 * 8
    slli t1, s0, 1      # s0 * 2
    add  s0, t0, t1     # s0 * 10
    addi t0, a0, -48    # dígito
    add  s0, s0, t0
    j    read_num1

got_op:
    mv   s2, a0         # guardar operador

# -----------------------------------------------------------------------------
# Leer segundo número — termina con ENTER (0x0D)
# -----------------------------------------------------------------------------
read_num2:
    call uart_getchar
    call uart_putchar   # echo

    li   t0, 0x0D       # ENTER
    beq  a0, t0, do_calc

    li   t0, 48
    blt  a0, t0, read_num2
    li   t0, 57
    bgt  a0, t0, read_num2

digit2:
    slli t0, s1, 3
    slli t1, s1, 1
    add  s1, t0, t1
    addi t0, a0, -48
    add  s1, s1, t0
    j    read_num2

# -----------------------------------------------------------------------------
# Calcular
# -----------------------------------------------------------------------------
do_calc:
    li   t0, 43         # '+'
    beq  s2, t0, do_add
    sub  s0, s0, s1
    j    send_result
do_add:
    add  s0, s0, s1

# -----------------------------------------------------------------------------
# Enviar resultado
# -----------------------------------------------------------------------------
send_result:
    li   a0, 61         # '='
    call uart_putchar

    mv   a0, s0
    call uart_printint

    li   a0, 0x0D       # CR
    call uart_putchar
    li   a0, 0x0A       # LF
    call uart_putchar

    j    main_loop

# =============================================================================
# uart_getchar: espera byte por UART
# Retorna: a0 = carácter
# =============================================================================
uart_getchar:
    li   t0, 0x02010
wait_rx:
    lw   t1, 0(t0)
    andi t1, t1, 2      # bit1 = new_rx
    beqz t1, wait_rx

    lw   a0, 12(t0)     # leer 0x0201C (offset 12 desde 0x02010)

    # Limpiar new_rx escribiendo 0 en control
    sw   zero, 0(t0)
    ret

# =============================================================================
# uart_putchar: envía byte por UART
# Parámetros: a0 = carácter
# =============================================================================
uart_putchar:
    li   t0, 0x02010
wait_tx:
    lw   t1, 0(t0)
    andi t1, t1, 1      # bit0 = send (ocupado si es 1)
    bnez t1, wait_tx

    li   t2, 0x02018
    sw   a0, 0(t2)      # escribir dato TX

    lw   t1, 0(t0)      # leer control actual
    ori  t1, t1, 1      # activar bit0 = send
    sw   t1, 0(t0)
    ret

# =============================================================================
# uart_printint: imprime entero con signo por UART
# Parámetros: a0 = número
# =============================================================================
uart_printint:
    addi sp, sp, -24
    sw   ra, 20(sp)
    sw   s3, 16(sp)
    sw   s4, 12(sp)

    mv   s3, a0         # guardar número

    # ¿Negativo?
    bgez s3, printint_pos
    li   a0, 45         # '-'
    call uart_putchar
    neg  s3, s3

printint_pos:
    # Caso cero
    bnez s3, printint_convert
    li   a0, 48         # '0'
    call uart_putchar
    j    printint_done

printint_convert:
    li   s4, 0          # contador de dígitos en stack
    mv   t3, s3

push_digits:
    beqz t3, pop_digits

    # t1 = t3 % 10 usando división por resta
    mv   a0, t3
    call div10          # retorna: a0=cociente, a1=resto

    addi a1, a1, 48     # dígito ASCII
    addi sp, sp, -4
    sw   a1, 0(sp)
    addi s4, s4, 1
    mv   t3, a0
    j    push_digits

pop_digits:
    beqz s4, printint_done
    lw   a0, 0(sp)
    addi sp, sp, 4
    addi s4, s4, -1
    call uart_putchar
    j    pop_digits

printint_done:
    lw   s4, 12(sp)
    lw   s3, 16(sp)
    lw   ra, 20(sp)
    addi sp, sp, 24
    ret

# =============================================================================
# div10: divide a0 entre 10 sin usar div
# Retorna: a0 = cociente, a1 = resto
# Método: resta sucesiva (funciona bien para números de hasta 4 dígitos)
# =============================================================================
div10:
    li   a1, 0          # cociente
    li   t0, 10
div10_loop:
    blt  a0, t0, div10_done
    sub  a0, a0, t0
    addi a1, a1, 1
    j    div10_loop
div10_done:
    # a0 = resto, a1 = cociente — intercambiar
    mv   t0, a0
    mv   a0, a1
    mv   a1, t0
    ret
