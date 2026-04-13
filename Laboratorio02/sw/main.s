# =============================================================================
# main.s
# -----------------------------------------------------------------------------
# Programa principal para el microcontrolador RV32I
# Recibe expresiones aritméticas por UART (ej: 1234+5678)
# Calcula el resultado y lo responde por UART
#
# Mapa de memoria:
#   0x02000 -> Switches/Botones
#   0x02004 -> LEDs
#   0x02010 -> UART Control (bit0=new_rx, bit1=send)
#   0x02018 -> UART TX (dato a enviar)
#   0x0201C -> UART RX (dato recibido)
# =============================================================================

.section .text
.globl _start

_start:
# -----------------------------------------------------------------------------
# 1. Inicializar stack pointer
# -----------------------------------------------------------------------------
    li   sp, 0x0007FFFC         # tope de RAM según mapa de memoria

# -----------------------------------------------------------------------------
# 2. Encender todos los LEDs — señal de "sistema listo"
# -----------------------------------------------------------------------------
    li   t0, 0x02004            # dirección registro LEDs
    li   t1, 0x0000FFFF         # 16 LEDs encendidos
    sw   t1, 0(t0)              # escribir en LEDs

# -----------------------------------------------------------------------------
# 3. Loop principal — espera y procesa expresiones indefinidamente
# -----------------------------------------------------------------------------
main_loop:
    # Registros usados:
    # s0 = primer número acumulado
    # s1 = segundo número acumulado
    # s2 = operador (43='+', 45='-')
    # s3 = dirección base UART control
    # s4 = carácter recibido actual

    li   s0, 0                  # limpiar primer número
    li   s1, 0                  # limpiar segundo número
    li   s2, 0                  # limpiar operador
    li   s3, 0x02010            # dirección UART control

# -----------------------------------------------------------------------------
# 4. Leer primer número (máximo 4 dígitos, termina con + o -)
# -----------------------------------------------------------------------------
read_num1:
    call uart_getchar           # a0 = carácter recibido
    call uart_putchar           # echo del carácter

    # ¿Es dígito? (ASCII '0'=48, '9'=57)
    li   t0, 48
    blt  a0, t0, read_num1     # menor que '0' → ignorar
    li   t0, 57
    ble  a0, t0, digit_num1    # entre '0' y '9' → es dígito

    # ¿Es operador?
    li   t0, 43                 # '+'
    beq  a0, t0, got_operator
    li   t0, 45                 # '-'
    beq  a0, t0, got_operator
    j    read_num1              # otro carácter → ignorar

digit_num1:
    # num1 = num1 * 10 + (char - '0')
    li   t0, 10
    mul  s0, s0, t0             # NOTE: si no hay MUL, usar shift+add
    addi t1, a0, -48            # char - '0'
    add  s0, s0, t1
    j    read_num1

got_operator:
    mv   s2, a0                 # guardar operador

# -----------------------------------------------------------------------------
# 5. Leer segundo número (termina con ENTER = 0x0D)
# -----------------------------------------------------------------------------
read_num2:
    call uart_getchar
    call uart_putchar           # echo

    # ¿Es ENTER? (0x0D = CR)
    li   t0, 0x0D
    beq  a0, t0, do_calc

    # ¿Es dígito?
    li   t0, 48
    blt  a0, t0, read_num2
    li   t0, 57
    bgt  a0, t0, read_num2

    # num2 = num2 * 10 + (char - '0')
    li   t0, 10
    mul  s1, s1, t0
    addi t1, a0, -48
    add  s1, s1, t1
    j    read_num2

# -----------------------------------------------------------------------------
# 6. Calcular resultado
# -----------------------------------------------------------------------------
do_calc:
    li   t0, 43                 # '+'
    beq  s2, t0, do_add
    sub  s0, s0, s1             # resta: resultado en s0
    j    send_result
do_add:
    add  s0, s0, s1             # suma: resultado en s0

# -----------------------------------------------------------------------------
# 7. Enviar "=" seguido del resultado
# -----------------------------------------------------------------------------
send_result:
    li   a0, 61                 # '='
    call uart_putchar

    mv   a0, s0                 # resultado a imprimir
    call uart_printint          # enviar número por UART

    li   a0, 0x0D               # CR
    call uart_putchar
    li   a0, 0x0A               # LF
    call uart_putchar

    j    main_loop              # volver al inicio

# =============================================================================
# SUBRUTINAS
# =============================================================================

# -----------------------------------------------------------------------------
# uart_getchar: espera y retorna un byte recibido por UART
# Retorna: a0 = carácter recibido
# -----------------------------------------------------------------------------
uart_getchar:
    li   t0, 0x02010            # UART control
wait_rx:
    lw   t1, 0(t0)              # leer registro de control
    andi t1, t1, 1              # bit 0 = new_rx
    beqz t1, wait_rx            # esperar hasta que haya dato

    lw   a0, 12(t0)             # leer dato de 0x0201C (offset 12 desde 0x02010)

    # Limpiar new_rx escribiendo 0 en control
    sw   zero, 0(t0)
    ret

# -----------------------------------------------------------------------------
# uart_putchar: envía un byte por UART
# Parámetros: a0 = carácter a enviar
# -----------------------------------------------------------------------------
uart_putchar:
    li   t0, 0x02010            # UART control
wait_tx:
    lw   t1, 0(t0)              # leer control
    andi t1, t1, 2              # bit 1 = send (ocupado si está en 1)
    bnez t1, wait_tx            # esperar hasta que TX esté libre

    li   t2, 0x02018            # UART TX data
    sw   a0, 0(t2)              # escribir dato

    lw   t1, 0(t0)              # leer control actual
    ori  t1, t1, 2              # activar bit send
    sw   t1, 0(t0)              # disparar transmisión
    ret

# -----------------------------------------------------------------------------
# uart_printint: envía un entero con signo por UART en ASCII
# Parámetros: a0 = número a imprimir
# Usa el stack para guardar dígitos en orden
# -----------------------------------------------------------------------------
uart_printint:
    addi sp, sp, -20            # reservar espacio en stack
    sw   ra, 16(sp)             # guardar return address

    # ¿Negativo?
    bgez a0, printint_pos
    li   t0, 45                 # '-'
    mv   t1, a0
    mv   a0, t0
    call uart_putchar
    mv   a0, t1
    neg  a0, a0                 # convertir a positivo

printint_pos:
    # Caso especial: número es 0
    bnez a0, printint_convert
    li   a0, 48                 # '0'
    call uart_putchar
    j    printint_done

printint_convert:
    # Extraer dígitos en orden inverso usando stack
    li   t2, 0                  # contador de dígitos
    mv   t3, a0                 # número a convertir

printint_loop:
    beqz t3, printint_send
    li   t0, 10
    rem  t1, t3, t0             # dígito = número % 10
    div  t3, t3, t0             # número = número / 10
    addi t1, t1, 48             # convertir a ASCII
    addi sp, sp, -4
    sw   t1, 0(sp)              # guardar en stack
    addi t2, t2, 1
    j    printint_loop

printint_send:
    beqz t2, printint_done
    lw   a0, 0(sp)              # sacar dígito del stack
    addi sp, sp, 4
    addi t2, t2, -1
    call uart_putchar
    j    printint_send

printint_done:
    lw   ra, 16(sp)
    addi sp, sp, 20
    ret
