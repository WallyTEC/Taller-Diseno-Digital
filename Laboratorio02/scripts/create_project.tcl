## ============================================================================
## Archivo      : scripts/create_project.tcl
## Autor        : WallyCR + Claude
## Fecha        : 21 de abril de 2026
## Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
## Descripción  : Crea el proyecto Vivado del Lab 2 desde cero, apuntando
##                a todos los archivos del repo. Idempotente: si el
##                proyecto ya existe, lo borra y lo recrea.
##
## Uso:
##   1. Cerrar cualquier instancia de Vivado con el proyecto abierto.
##   2. Abrir Vivado (sin proyecto).
##   3. En la Tcl Console:
##        cd /home/wally/Documentos/Taller-Diseno-Digital/Laboratorio02
##        source scripts/create_project.tcl
##   4. El proyecto queda listo para síntesis.
##
## El proyecto se crea en:
##   /home/wally/Documentos/Vivado/2024.1/lab02_clean/
##
## (No tocamos el proyecto viejo lab02/ por si querés recuperar algo.)
## ============================================================================

set repo_dir [pwd]
set proj_name "lab02_clean"
set proj_dir "/home/wally/Documentos/Vivado/2024.1/$proj_name"
set part "xc7a100tcsg324-1"

puts "==========================================="
puts "Creando proyecto Vivado Lab 2"
puts "  Repo: $repo_dir"
puts "  Proy: $proj_dir"
puts "==========================================="

## Si el proyecto existe, cerrarlo y borrarlo
if {[file exists $proj_dir]} {
    puts "INFO: proyecto previo detectado, removiendo..."
    catch {close_project}
    file delete -force $proj_dir
}

## Crear el proyecto
create_project $proj_name $proj_dir -part $part -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

## ----------------------------------------------------------------------------
## Agregar sources de diseño (design_sources)
## ----------------------------------------------------------------------------
puts "\n[1/6] Agregando sources de diseño..."

set design_files [list \
    "$repo_dir/rtl/bus/axil_defs.svh" \
    "$repo_dir/rtl/bus/axil_interconnect.sv" \
    "$repo_dir/rtl/core/picorv32.v" \
    "$repo_dir/rtl/memory/rom_axil.sv" \
    "$repo_dir/rtl/memory/ram_axil.sv" \
    "$repo_dir/rtl/memory/rom_axil_with_ip.sv" \
    "$repo_dir/rtl/memory/ram_axil_with_ip.sv" \
    "$repo_dir/rtl/peripherals/gpio_leds_axil.sv" \
    "$repo_dir/rtl/peripherals/gpio_sw_btn_axil.sv" \
    "$repo_dir/rtl/peripherals/uart/uart_axil.sv" \
    "$repo_dir/rtl/peripherals/uart/uart_baud_gen.sv" \
    "$repo_dir/rtl/peripherals/uart/uart_tx.sv" \
    "$repo_dir/rtl/peripherals/uart/uart_rx.sv" \
    "$repo_dir/rtl/util/synchronizer.sv" \
    "$repo_dir/rtl/util/debouncer.sv" \
    "$repo_dir/rtl/util/reset_sync.sv" \
    "$repo_dir/rtl/top.sv" \
]

add_files -norecurse -fileset sources_1 $design_files

## Forzar tipo SystemVerilog para todos los .sv y el header .svh
foreach f [get_files *.sv -of_objects [get_filesets sources_1]] {
    set_property file_type SystemVerilog $f
}
foreach f [get_files *.svh -of_objects [get_filesets sources_1]] {
    set_property file_type "Verilog Header" $f
    set_property is_global_include true $f
}

## Include dir para que cualquier archivo encuentre axil_defs.svh
set_property include_dirs "$repo_dir/rtl/bus" [get_filesets sources_1]

## Top module
set_property top top [get_filesets sources_1]

puts "      [llength $design_files] archivos de diseño agregados"

## ----------------------------------------------------------------------------
## Constraints
## ----------------------------------------------------------------------------
puts "\n[2/6] Agregando constraints..."

add_files -fileset constrs_1 -norecurse "$repo_dir/constraints/nexys4ddr.xdc"
puts "      nexys4ddr.xdc agregado"

## ----------------------------------------------------------------------------
## Simulation sources (al sim_1 por defecto)
## ----------------------------------------------------------------------------
puts "\n[3/6] Agregando simulation sources..."

set sim_files [list \
    "$repo_dir/sim/common/axil_master_bfm.sv" \
    "$repo_dir/sim/tb_axil_interconnect.sv" \
    "$repo_dir/sim/tb_gpio_leds_axil.sv" \
    "$repo_dir/sim/tb_gpio_sw_btn_axil.sv" \
    "$repo_dir/sim/tb_uart_axil.sv" \
    "$repo_dir/sim/tb_uart_loopback.sv" \
]

add_files -fileset sim_1 -norecurse $sim_files

foreach f [get_files *.sv -of_objects [get_filesets sim_1]] {
    set_property file_type SystemVerilog $f
}

set_property include_dirs "$repo_dir/rtl/bus" [get_filesets sim_1]
set_property top tb_axil_interconnect [get_filesets sim_1]

puts "      [llength $sim_files] archivos de sim agregados"
puts "      Top de sim_1: tb_axil_interconnect (cambiar con set_property top)"

## ----------------------------------------------------------------------------
## IPs
## ----------------------------------------------------------------------------
puts "\n[4/6] Creando IPs (PLL, ROM, RAM)..."

source "$repo_dir/ip/clk_wiz_main.tcl"
source "$repo_dir/ip/rom_program.tcl"
source "$repo_dir/ip/data_ram.tcl"

## ----------------------------------------------------------------------------
## Update compile order
## ----------------------------------------------------------------------------
puts "\n[5/6] Actualizando orden de compilación..."
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

## ----------------------------------------------------------------------------
## Resumen
## ----------------------------------------------------------------------------
puts "\n[6/6] Proyecto creado exitosamente!"
puts "==========================================="
puts "Siguiente paso:"
puts "  1. Verificar que no hay errores de parse:"
puts "     report_compile_order -fileset sources_1"
puts ""
puts "  2. Correr síntesis:"
puts "     launch_runs synth_1 -jobs 4"
puts "     wait_on_run synth_1"
puts ""
puts "  3. Ver resultados:"
puts "     open_run synth_1"
puts ""
puts "  Para simular un TB específico (ej: loopback):"
puts "     set_property top tb_uart_loopback \\"
puts "         \[get_filesets sim_1\]"
puts "     launch_simulation"
puts "==========================================="
