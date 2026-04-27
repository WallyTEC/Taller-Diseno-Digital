#!/bin/bash
# =============================================================================
# Archivo      : sw/build.sh
# Autor        : WallyCR
# Descripcion  : Compila calc.s -> calc.elf -> calc.bin -> main.coe
#                Pensado para correrse desde la raiz del repo Laboratorio02.
# Uso          : bash sw/build.sh
# =============================================================================
set -e

# Rutas relativas a la raiz del repo
ASM_SRC="sw/asm/calc.s"
LD_SCRIPT="sw/ld/link.ld"
BUILD_DIR="sw/build"
OBJ="$BUILD_DIR/calc.o"
ELF="$BUILD_DIR/calc.elf"
BIN="$BUILD_DIR/calc.bin"
COE="$BUILD_DIR/main.coe"

# Toolchain
TOOL=riscv64-unknown-elf

echo ">>> 1/4 Ensamblando $ASM_SRC ..."
$TOOL-as -march=rv32i -mabi=ilp32 -o "$OBJ" "$ASM_SRC"

echo ">>> 2/4 Enlazando con $LD_SCRIPT ..."
$TOOL-ld -m elf32lriscv -T "$LD_SCRIPT" -o "$ELF" "$OBJ"

echo ">>> 3/4 Extrayendo binario plano ..."
$TOOL-objcopy -O binary "$ELF" "$BIN"

echo ">>> 4/4 Convirtiendo a .coe ..."
python3 "$BUILD_DIR/bin2coe.py" "$BIN" "$COE"

echo ""
echo "Listo. Archivos generados:"
echo "  ELF: $(realpath "$ELF")"
echo "  BIN: $(realpath "$BIN")  ($(wc -c < "$BIN") bytes)"
echo "  COE: $(realpath "$COE")"
