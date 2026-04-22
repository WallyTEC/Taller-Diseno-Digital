## ============================================================================
## Archivo      : ip/clk_wiz_main.tcl
## Autor        : WallyCR
## Fecha        : 20 de abril de 2026
## Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
## Descripción  : Crea el IP Clocking Wizard 'clk_wiz_main' en el proyecto
##                Vivado activo. Configuración: 100 MHz in -> 50 MHz out
##                con MMCM, locked output activo.
##
## Uso:
##   En la consola Tcl de Vivado, con el proyecto abierto:
##     source ip/clk_wiz_main.tcl
##
##   Vivado va a:
##     1. Crear el IP en /ip/clk_wiz_main/
##     2. Generar los productos (output products) automáticamente
##     3. El IP queda listo para ser instanciado desde top.sv
##
## Si el IP ya existe, lo borra y lo recrea (idempotente).
## ============================================================================

set ip_name "clk_wiz_main"

if {[get_ips -quiet $ip_name] ne ""} {
    puts "INFO: removiendo IP existente $ip_name"
    export_ip_user_files -of_objects [get_files ${ip_name}.xci] -no_script -reset -force -quiet
    remove_files -quiet [get_files ${ip_name}.xci]
}

create_ip -name clk_wiz \
          -vendor xilinx.com \
          -library ip \
          -module_name $ip_name

set_property -dict [list \
    CONFIG.PRIM_IN_FREQ          {100.000} \
    CONFIG.PRIM_SOURCE           {Single_ended_clock_capable_pin} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50.000} \
    CONFIG.USE_LOCKED            {true} \
    CONFIG.USE_RESET             {false} \
    CONFIG.RESET_TYPE            {ACTIVE_HIGH} \
    CONFIG.CLKIN1_JITTER_PS      {100.0} \
    CONFIG.CLK_OUT1_PORT         {clk_out1} \
    CONFIG.CLK_IN1_BOARD_INTERFACE {Custom} \
] [get_ips $ip_name]

generate_target {instantiation_template synthesis simulation} [get_files [get_property IP_FILE [get_ips $ip_name]]]

puts "INFO: IP $ip_name creado correctamente"
puts "      Entrada:  100 MHz (clk_in1)"
puts "      Salida:    50 MHz (clk_out1)"
puts "      Locked:    true"
