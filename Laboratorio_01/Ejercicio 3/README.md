# Ejercicio 3 – Modulación por Ancho de Pulso (PWM)

## Descripción

Este ejercicio consiste en diseñar un módulo digital secuencial que reciba como entrada un código de 4 bits proveniente de interruptores físicos de la FPGA y genere como salida una señal PWM (Modulación por Ancho de Pulso) con un período aproximado de 1 ms, la cual se conectará a un LED para observar variaciones en el brillo según el ciclo de trabajo seleccionado.

---

## Objetivo

Implementar un bloque completamente sintetizable que:

- Reciba un bus de 4 bits desde los switches.
- Genere una señal PWM proporcional al valor ingresado.
- Mantenga un período fijo de aproximadamente 1 ms.
- No genere latches.
- Sea validado mediante testbench.

---

## Especificaciones técnicas

- **Entrada:** `sw[3:0]`
- **Salida:** `pwm_out`
- **Frecuencia del reloj:** 100 MHz
- **Frecuencia PWM:** ~1 kHz
- **Resolución:** 16 niveles de duty cycle (4 bits)
- **Operación:**
  - Cálculo de `threshold = (duty_code × PERIOD_CYCLES) / 15`
  - Generación de señal PWM mediante comparación:

    `pwm_out = 1 si counter < threshold`

---

## Tipo de diseño

- Lógica secuencial (contador síncrono).
- Lógica combinacional (cálculo de threshold y comparador).
- Descripción en SystemVerilog.
- Diseño sintetizable para FPGA.

---

## Validación

Se desarrolló un testbench que:

- Genera reloj de 100 MHz.
- Aplica diferentes valores de `duty_code`.
- Permite observar la forma de onda PWM.
- Verifica que el período y el duty cycle correspondan al valor esperado.

Además, se realizó validación en hardware conectando la salida PWM a un LED para observar variaciones de brillo.
