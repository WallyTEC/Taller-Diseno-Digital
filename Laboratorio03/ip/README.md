## Filosofía: scripts vs. archivos generados

Los IPs en Vivado generan muchos archivos derivados (`.xci`, `.dcp`, `.veo`, `.xml`, etc.) que:
- Son específicos de la versión de Vivado
- Cambian con el sistema operativo y la ruta del proyecto
- Pueden regenerarse desde un script Tcl

Por eso, este repo solo versiona los **scripts Tcl** (declarativos, ~50 líneas cada uno) y deja a Vivado regenerar los productos en cada máquina.

## Cómo usar los scripts

Con un proyecto Vivado abierto, en la consola Tcl:

```tcl
cd /ruta/al/repo/Laboratorio02
source ip/clk_wiz_main.tcl
source ip/data_ram.tcl
source ip/rom_program.tcl
```

Cada script:
1. Verifica si el IP ya existe (lo borra si sí)
2. Crea el IP con `create_ip`
3. Configura sus parámetros con `set_property`
4. Genera los output products

## Descripción de cada IP

### `clk_wiz_main.tcl` — PLL (Clocking Wizard)

Genera un IP `clk_wiz_main` que toma el reloj de 100 MHz del oscilador externo y produce un reloj de sistema de 50 MHz.

| Parámetro | Valor |
|---|---|
| Primitive | MMCM |
| Input freq | 100.000 MHz |
| Output freq | 50.000 MHz |
| Locked output | Sí |
| Reset input | No |

**Pines del IP:** `clk_in1`, `clk_out1`, `locked`.

### `data_ram.tcl` — RAM de datos (Block Memory Generator)

Genera un IP `data_ram` para la memoria RAM de datos del sistema. Soporta byte write enable para que las instrucciones `sb` y `sh` de RV32I funcionen correctamente.

| Parámetro | Valor |
|---|---|
| Memory Type | Single Port RAM |
| Width | 32 bits |
| Depth | 25600 (= 100 KiB) |
| Byte Write Enable | Sí (4 bytes) |
| ENA pin | Sí (controlado por wrapper) |
| Output Register | No (latencia 1 ciclo) |
| Init file | No (RAM arranca en ceros) |

**Pines del IP:** `clka`, `ena`, `wea[3:0]`, `addra[14:0]`, `dina[31:0]`, `douta[31:0]`.

**Recursos:** ~25 BRAM36.

### `rom_program.tcl` — ROM de programa (Block Memory Generator)

Genera un IP `rom_program` para la memoria de programa, **inicializado desde `main.coe`**. Esta ROM contiene el código RV32I que ejecutará el procesador al hacer reset.

| Parámetro | Valor |
|---|---|
| Memory Type | Single Port ROM |
| Width | 32 bits |
| Depth | 512 (= 2 KiB) |
| Operating Mode | Read First |
| ENA pin | No (Always Enabled) |
| Output Register | No (latencia 1 ciclo) |
| Init file | `coe/main.coe` |

**Pines del IP:** `clka`, `addra[8:0]`, `douta[31:0]`.

**Recursos:** 1 BRAM18.

#### Búsqueda del archivo `.coe`

El script `rom_program.tcl` busca el archivo `main.coe` en varias rutas relativas comunes (relativo al `cwd` y al directorio del proyecto). Si no lo encuentra, genera la ROM en ceros y emite un warning.

Para forzar una ruta específica antes de ejecutar el script:

```tcl
set coe_file "/ruta/absoluta/al/main.coe"
source ip/rom_program.tcl
```

> **Importante:** Vivado guarda el path del `.coe` como **relativo al directorio del IP**. Si el `.coe` está fuera del proyecto Vivado y se mueve, la ruta puede romperse y el IP queda con la ROM vacía. **Recomendación:** mantener una copia del `.coe` dentro del proyecto Vivado (por ejemplo, en `<proyecto>/coe/main.coe`).

## Flujo de regeneración de la ROM al cambiar el programa

Cada vez que se modifica el programa (`.s` o `.c`) hay que regenerar el `.coe` y reinyectarlo en la ROM:

```bash
# 1. Compilar el programa nuevo
cd sw
riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -ffreestanding -nostdlib \
    -c asm/calc.s -o build/calc.o
riscv-none-elf-ld -m elf32lriscv -T ld/link.ld build/calc.o -o build/calc.elf
riscv-none-elf-objcopy -O binary build/calc.elf build/calc.bin

# 2. Convertir a .coe (script Python en sw/)
python3 bin_to_coe.py build/calc.bin build/main.coe

# 3. Copiar al directorio del proyecto Vivado
cp build/main.coe /ruta/al/proyecto/Vivado/coe/main.coe
```

Después en Vivado:

```tcl
# Forzar regeneración del IP con el .coe nuevo
reset_target all [get_ips rom_program]
generate_target all [get_ips rom_program]
synth_ip [get_ips rom_program]

# Re-sintetizar el top y generar bitstream
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
```

O equivalentemente, en la GUI: **Sources → IP Sources → `rom_program.xci` → click derecho → Reset Output Products → Generate Output Products → Generate Bitstream**.

## Dependencias

- **Vivado 2024.1** o superior
- Target FPGA: **xc7a100tcsg324-1** (Nexys4 DDR)
- Para `rom_program`: archivo `main.coe` accesible (generado desde el toolchain RISC-V — ver `../sw/`)

## Notas de troubleshooting

- **Si el IP no carga el `.coe`:** verificar con `get_property CONFIG.Coe_File [get_ips rom_program]` y `get_property CONFIG.Load_Init_File [get_ips rom_program]`. El segundo debe ser `true` y el primero debe apuntar al `.coe` correcto.
- **Si después de cambiar el `.coe` el comportamiento no cambia:** Vivado cachea los `.dcp` de los IPs. Hay que hacer **Reset Output Products + Generate Output Products** explícitamente, no solo re-sintetizar el top.
- **Si Vivado dice "synthesis checkpoint already up-to-date"** pero el bitstream sigue con la ROM vieja, eliminar los archivos generados manualmente:

```bash
  rm -rf <proyecto>/<proyecto>.gen/sources_1/ip/rom_program*
  rm -rf <proyecto>/<proyecto>.runs/rom_program_synth_1
```

  y volver a correr `source ip/rom_program.tcl`.
