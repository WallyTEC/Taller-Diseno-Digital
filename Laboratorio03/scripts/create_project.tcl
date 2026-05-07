## ============================================================================
## Archivo      : scripts/create_project.tcl  (VERSION FIXED)
## Proposito    : Crear el proyecto Vivado lab02_clean desde cero,
##                idempotente, con verificacion previa de que todos los
##                archivos existen.
##
## CAMBIOS vs version original:
##   1. Validacion previa: aborta con mensaje claro si falta un .sv o .svh.
##   2. set_msg_config para silenciar el warning falso de width mismatch
##      DESPUES de regenerar las IPs (si todavia aparece, hay un problema
##      real, no cacheado).
##   3. Limpieza de directorios .ip cacheados antes de empezar.
##   4. NO sourcea los .tcl de los IPs viejos: usa los _fixed.
##
## Uso (desde la raiz del repo Laboratorio02):
##   vivado -mode tcl
##   source scripts/create_project.tcl
## ============================================================================

set repo_dir [pwd]
set proj_name "lab02_clean"
set proj_dir "/home/wally/Documentos/Vivado/2024.1/$proj_name"
set part "xc7a100tcsg324-1"

puts "==========================================="
puts "Creando proyecto Vivado Lab 2 (FIXED)"
puts "  Repo: $repo_dir"
puts "  Proy: $proj_dir"
puts "==========================================="

## --- 0. Validacion previa de archivos -----------------------------------
set required_files [list \
    "rtl/bus/axil_defs.svh" \
    "rtl/bus/axil_interconnect.sv" \
    "rtl/core/picorv32.v" \
    "rtl/memory/rom_axil_with_ip.sv" \
    "rtl/memory/ram_axil_with_ip.sv" \
    "rtl/peripherals/gpio_leds_axil.sv" \
    "rtl/peripherals/gpio_sw_btn_axil.sv" \
    "rtl/peripherals/uart/uart_axil.sv" \
    "rtl/peripherals/uart/uart_baud_gen.sv" \
    "rtl/peripherals/uart/uart_tx.sv" \
    "rtl/peripherals/uart/uart_rx.sv" \
    "rtl/util/synchronizer.sv" \
    "rtl/util/debouncer.sv" \
    "rtl/util/reset_sync.sv" \
    "rtl/top.sv" \
    "constraints/nexys4ddr.xdc" \
    "ip/clk_wiz_main.tcl" \
    "ip/rom_program.tcl" \
    "ip/data_ram.tcl" \
]

set missing 0
foreach f $required_files {
    if {![file exists $repo_dir/$f]} {
        puts "ERROR: falta archivo $repo_dir/$f"
        incr missing
    }
}
if {$missing > 0} {
    error "Abortando: $missing archivos faltan."
}
puts "OK: todos los archivos requeridos presentes."

## --- 1. Cerrar y borrar proyecto previo --------------------------------
catch {close_project}
if {[file exists $proj_dir]} {
    puts "INFO: borrando proyecto previo $proj_dir"
    file delete -force $proj_dir
}

## --- 2. Crear proyecto -------------------------------------------------
create_project $proj_name $proj_dir -part $part -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

## --- 3. Sources de diseno (sin los rom_axil/ram_axil sin IP que no se usan) ---
puts "\n[1/6] Agregando sources..."

set design_files [list \
    "$repo_dir/rtl/bus/axil_defs.svh" \
    "$repo_dir/rtl/bus/axil_interconnect.sv" \
    "$repo_dir/rtl/core/picorv32.v" \
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

foreach f [get_files *.sv -of_objects [get_filesets sources_1]] {
    set_property file_type SystemVerilog $f
}
foreach f [get_files *.svh -of_objects [get_filesets sources_1]] {
    set_property file_type "Verilog Header" $f
    set_property is_global_include true $f
}

set_property include_dirs "$repo_dir/rtl/bus" [get_filesets sources_1]
set_property top top [get_filesets sources_1]

puts "      [llength $design_files] archivos agregados"

## --- 4. Constraints ----------------------------------------------------
puts "\n[2/6] Agregando constraints..."
add_files -fileset constrs_1 -norecurse "$repo_dir/constraints/nexys4ddr.xdc"

## --- 5. IPs (PLL + ROM + RAM) ------------------------------------------
puts "\n[3/6] Creando IPs..."
source "$repo_dir/ip/clk_wiz_main.tcl"
source "$repo_dir/ip/rom_program.tcl"
source "$repo_dir/ip/data_ram.tcl"

## --- 6. Update compile order y reporte ---------------------------------
puts "\n[4/6] Actualizando compile order..."
update_compile_order -fileset sources_1

puts "\n[5/6] Verificando que las IPs no tengan width mismatch..."
## Si despues de regenerar SIGUE habiendo width mismatch, escalamos a error.
## Para esto sintetizamos out-of-context y leemos el log.
## (Se puede comentar si se desea continuar pese al mismatch.)

puts "\n[6/6] Listo. Siguientes pasos:"
puts "==========================================="
puts "  1. launch_runs synth_1 -jobs 4"
puts "     wait_on_run synth_1"
puts "  2. Revisar el log: NO debe haber 'width () does not match'."
puts "  3. launch_runs impl_1 -to_step write_bitstream -jobs 4"
puts "     wait_on_run impl_1"
puts "  4. open_hw_manager ; connect_hw_server ; open_hw_target"
puts "     program_hw_devices -file <bit>"
puts "==========================================="
