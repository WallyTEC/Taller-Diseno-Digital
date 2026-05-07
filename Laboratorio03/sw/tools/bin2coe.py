#!/usr/bin/env python3
# =============================================================================
# Archivo      : sw/tools/bin2coe.py
# Autor        : WallyCR
# Descripcion  : Convierte un .bin (raw, little-endian, 32-bit words) al
#                formato .coe que espera el IP Block Memory Generator de Vivado.
#                Hace padding con ceros hasta llenar las 512 palabras de la ROM.
# Uso          : python3 bin2coe.py <input.bin> <output.coe>
# =============================================================================
import sys, struct

if len(sys.argv) != 3:
    print("Uso: bin2coe.py <input.bin> <output.coe>")
    sys.exit(1)

with open(sys.argv[1], "rb") as f:
    data = f.read()

# Pad a multiplo de 4 bytes (por si el .bin no esta alineado)
if len(data) % 4 != 0:
    data += b"\x00" * (4 - len(data) % 4)

words = list(struct.unpack(f"<{len(data) // 4}I", data))

# Padding hasta 512 palabras (tamano de la ROM)
ROM_DEPTH = 512
n_real = len(words)
if n_real > ROM_DEPTH:
    print(f"ERROR: programa de {n_real} palabras > ROM de {ROM_DEPTH}")
    sys.exit(1)
words += [0] * (ROM_DEPTH - n_real)

with open(sys.argv[2], "w") as f:
    f.write("memory_initialization_radix=16;\n")
    f.write("memory_initialization_vector=\n")
    for i, w in enumerate(words):
        sep = ";" if i == len(words) - 1 else ","
        f.write(f"{w:08X}{sep}\n")

print(f"OK: {sys.argv[2]} generado")
print(f"    {n_real} palabras de programa, {ROM_DEPTH - n_real} de padding (ceros)")

