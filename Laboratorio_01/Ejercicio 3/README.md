# Ejercicio 3 – Modulación por Ancho de Pulso (PWM)

## Descripción
Módulo digital secuencial que recibe un código de 4 bits desde interruptores físicos
y genera una señal PWM con período de 1 ms, conectada a un LED para observar
variaciones de brillo según el ciclo de trabajo seleccionado.

---

## Especificaciones técnicas
| Parámetro | Valor |
|---|---|
| Entrada | `sw[3:0]` (4 interruptores) |
| Salida | `pwm_out` → LED0 |
| Frecuencia de reloj | 100 MHz |
| Período PWM | 1 ms (~1 kHz) |
| Resolución | 16 niveles (4 bits) |
| Ciclos por período | 100,000 |
| Ciclos por nivel | 6,250 |

---

## Archivos
```
src/
├── pwm_4bit.sv   # Módulo principal PWM
├── top.sv        # Módulo superior (mapeo de pines)
└── nexys4.xdc    # Constraints de la tarjeta
tb/
└── tb_pwm_4bit.sv  # Testbench exhaustivo
docs/
└── (screenshots, tablas, paper)
```

---

## Resultados del testbench

Se validaron 5 pruebas independientes sobre todos los valores posibles de entrada:

| Test | Descripción | Resultado |
|---|---|---|
| 1 | Reset asíncrono | ✅ PASS |
| 2 | Barrido completo duty 0–15 | ✅ 16/16 PASS |
| 3a | Caso límite duty=0 (siempre LOW) | ✅ PASS |
| 3b | Caso límite duty=15 (93,750/100,000) | ✅ PASS |
| 4 | Cambio dinámico 4→12 sin reset | ✅ PASS |
| 5 | Período medido = 1,000,000 ns | ✅ PASS |

![Resultados barrido 0-15](docs/Resultados.jpg)
![Testbench completado](docs/Resultados2.jpg)

---

## Validación en hardware
El diseño fue sintetizado sobre la Nexys 4 DDR (Artix-7). Al variar los
interruptores de `0000` a `1111` se observaron 16 niveles de brillo distintos
en el LED, confirmando el correcto funcionamiento en hardware.
