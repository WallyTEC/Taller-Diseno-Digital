## 1. Descripción General del Sistema
## 1.1 Introducción

El sistema desarrollado en SystemVerilog corresponde a una arquitectura digital modular orientada a la comunicación serial mediante UART. Su propósito es recibir datos, transmitir el mensaje “Hola mundo” al presionar un botón y mostrar en los LEDs el último byte recibido.

El diseño modular facilita la organización del circuito, la comprensión de su funcionamiento y el proceso de verificación por simulación.

## 1.2 Objetivo del Sistema

El sistema tiene como finalidad:

recibir señales de entrada,

procesarlas mediante lógica digital,

controlar la transmisión serial,

y generar salidas visibles en la interfaz física.

En este caso, la salida principal corresponde a la transmisión UART y a la visualización del dato recibido en los LEDs.

## 1.3 Arquitectura General

El sistema integra varios bloques funcionales dentro del módulo principal uart_top, entre ellos:

generador de baud rate,

receptor UART,

transmisor UART,

sincronizador del botón,

detector de flanco,

máquina de estados finitos (FSM),

lógica de actualización de LEDs.

Esta organización permite separar funciones y simplificar tanto el diseño como la depuración.

## 2. Arquitectura del Sistema

El módulo principal uart_top coordina todos los bloques del sistema. Su funcionamiento general puede resumirse así:

El sistema recibe datos seriales por la línea uart_rx.

Cuando un byte válido llega al receptor UART, este dato se almacena y se muestra en los LEDs.

Cuando el usuario presiona el botón btn_send, el sistema detecta el flanco de subida.

La FSM inicia la transmisión del mensaje “Hola mundo\r\n” carácter por carácter por la línea uart_tx.

Este comportamiento permite implementar una comunicación serial básica con capacidad de recepción y transmisión.

## 3. Representación ASCII

El sistema utiliza el estándar ASCII para representar caracteres en forma binaria. Esto resulta necesario porque la UART transmite bytes, no letras directamente. Por tanto, cada carácter del mensaje se almacena y transmite como su código ASCII correspondiente.
| Carácter | Decimal | Hexadecimal | Binario  |
| -------- | ------: | ----------: | -------- |
| H        |      72 |          48 | 01001000 |
| o        |     111 |          6F | 01101111 |
| l        |     108 |          6C | 01101100 |
| a        |      97 |          61 | 01100001 |
| espacio  |      32 |          20 | 00100000 |
| m        |     109 |          6D | 01101101 |
| u        |     117 |          75 | 01110101 |
| n        |     110 |          6E | 01101110 |
| d        |     100 |          64 | 01100100 |
| o        |     111 |          6F | 01101111 |
| CR       |      13 |          0D | 00001101 |
| LF       |      10 |          0A | 00001010 |

Importancia de CR y LF

Los caracteres CR (Carriage Return) y LF (Line Feed) son caracteres de control usados al final del mensaje:

CR mueve el cursor al inicio de la línea.

LF baja a la siguiente línea.

En terminales seriales, ambos permiten que el texto siguiente aparezca ordenadamente en una nueva línea.

## 4. Descripción de los Módulos
## 4.1 Módulo receptor UART

Se encarga de recibir los bits provenientes de la línea serial uart_rx, reconstruir el byte correspondiente y activar una señal de dato válido cuando la recepción termina correctamente.

## 4.2 Módulo transmisor UART

Convierte cada byte en una trama serial UART y la transmite por la línea uart_tx, respetando el protocolo de inicio, datos y parada.

## 4.3 Generador de baud rate

Produce la señal de temporización necesaria para que el receptor y el transmisor UART operen con la velocidad adecuada.

## 4.4 Sincronización y detección del botón

El botón físico btn_send pasa primero por un sincronizador de dos flip-flops para evitar problemas de metastabilidad. Luego, una lógica de detección de flanco genera un pulso de un ciclo (btn_rise) cuando se presiona el botón.

## 4.5 Registro de LEDs

Cuando el receptor UART indica que un byte fue recibido correctamente, dicho byte se guarda en un registro y se muestra en leds[7:0].

## 4.6 FSM de transmisión

La máquina de estados controla el envío secuencial del mensaje almacenado en memoria, avanzando carácter por carácter hasta completar la cadena.

## 5. Máquina de Estados Finitos (FSM)

La FSM es el bloque encargado de controlar el envío del mensaje por UART. Su operación se divide en tres estados principales:

S_IDLE: espera la pulsación del botón.

S_SEND: carga el byte actual e inicia su transmisión.

S_WAIT: espera a que finalice la transmisión del byte antes de continuar.

## Tabla resumida de estados

| Estado   | Función principal           |
| -------- | --------------------------- |
| `S_IDLE` | Espera activación del botón |
| `S_SEND` | Envía el carácter actual    |
| `S_WAIT` | Espera fin de transmisión   |

"## Tabla resumida de transición
| Estado actual | Condición                         | Estado siguiente |
| ------------- | --------------------------------- | ---------------- |
| `S_IDLE`      | `btn_rise = 1`                    | `S_SEND`         |
| `S_SEND`      | `tx_ready = 1`                    | `S_WAIT`         |
| `S_WAIT`      | `tx_busy = 0` y faltan caracteres | `S_SEND`         |
| `S_WAIT`      | `tx_busy = 0` y mensaje completo  | `S_IDLE`         |


## Diagrama de estados
<img width="1528" height="924" alt="image" src="https://github.com/user-attachments/assets/dafeac83-7c67-47f0-9e33-f9aa529edbc1" />

## 6. Verificación mediante Testbench

La validación del sistema se realiza con un testbench, el cual permite simular su comportamiento antes de implementarlo físicamente en la FPGA.

El testbench cumple las siguientes funciones:

genera señales de prueba,

aplica estímulos al diseño,

observa las salidas,

verifica la respuesta del sistema.

En la simulación se puede comprobar que:

el botón activa correctamente la transmisión,

la FSM avanza por los estados esperados,

el mensaje “Hola mundo” se transmite completo,

los LEDs muestran correctamente el último byte recibido.

Esto garantiza que el diseño funcione de forma coherente antes de su implementación real.

## 7. Tablas Resumidas del Módulo uart_top
## 7.1 Detector de flanco

La señal:

btn_rise = btn_sync & ~btn_sync_d;

permite detectar cuándo el botón pasa de 0 a 1.
| `btn_sync` | `btn_sync_d` | `btn_rise` |
| ---------: | -----------: | ---------: |
|          0 |            0 |          0 |
|          0 |            1 |          0 |
|          1 |            0 |          1 |
|          1 |            1 |          0 |

7.2 Actualización de LEDs
| `rst_n` | `rx_valid` | Resultado        |
| ------: | ---------: | ---------------- |
|       0 |          X | `leds = 8'h00`   |
|       1 |          0 | conserva valor   |
|       1 |          1 | `leds = rx_data` |

7.3 Señales principales
| Señal       | Tipo    | Descripción          |
| ----------- | ------- | -------------------- |
| `clk`       | entrada | reloj principal      |
| `rst_n`     | entrada | reset activo en bajo |
| `btn_send`  | entrada | inicia transmisión   |
| `uart_rx`   | entrada | recepción serial     |
| `uart_tx`   | salida  | transmisión serial   |
| `leds[7:0]` | salida  | último byte recibido |

## 8. Conclusiones

El módulo uart_top integra de manera adecuada los bloques principales de comunicación UART dentro de una arquitectura modular y funcional. La separación en submódulos permite un diseño más claro, reutilizable y fácil de verificar.
La máquina de estados implementada controla de forma ordenada la transmisión del mensaje “Hola mundo\r\n”, mientras que el detector de flanco garantiza una activación correcta a partir del botón físico. Además, la visualización del último byte recibido en los LEDs ofrece una forma simple y útil de comprobar el funcionamiento del sistema.
En conjunto, la simulación mediante testbench confirma que el diseño cumple con los requerimientos establecidos y que su comportamiento es consistente con la lógica esperada.
