# Tablas – Ejercicio 3: PWM de 4 bits

El módulo divide el período de 1 ms en 16 subperíodos iguales de 6,250 ciclos
mediante dos contadores anidados. La salida `pwm_out = 1` cuando `level_counter < duty`.

---

## Tabla de comportamiento del contador
| rst | Condición | counter |
|-----|-----------|---------|
| 1 | flanco positivo | 0 (reset) |
| 0 | counter < 6249 | counter + 1 |
| 0 | counter = 6249 | 0 (y level_counter + 1) |

---

## Tabla de verdad del comparador
| Condición | pwm_out |
|-----------|---------|
| duty = 0 | 0 (siempre apagado) |
| level_counter < duty | 1 |
| level_counter ≥ duty | 0 |

---

## Tabla de niveles PWM
Período total = 1 ms — Ciclos por nivel = 6,250

| duty_code | Ciclos HIGH | Ton (µs) | Duty (%) |
|-----------|-------------|----------|----------|
| 0  | 0      | 0.00   | 0.00  |
| 1  | 6,250  | 62.50  | 6.25  |
| 2  | 12,500 | 125.00 | 12.50 |
| 3  | 18,750 | 187.50 | 18.75 |
| 4  | 25,000 | 250.00 | 25.00 |
| 5  | 31,250 | 312.50 | 31.25 |
| 6  | 37,500 | 375.00 | 37.50 |
| 7  | 43,750 | 437.50 | 43.75 |
| 8  | 50,000 | 500.00 | 50.00 |
| 9  | 56,250 | 562.50 | 56.25 |
| 10 | 62,500 | 625.00 | 62.50 |
| 11 | 68,750 | 687.50 | 68.75 |
| 12 | 75,000 | 750.00 | 75.00 |
| 13 | 81,250 | 812.50 | 81.25 |
| 14 | 87,500 | 875.00 | 87.50 |
| 15 | 93,750 | 937.50 | 93.75 |

> El duty máximo es 93.75% ya que con 4 bits se alcanzan 15 de 16 niveles activos.
