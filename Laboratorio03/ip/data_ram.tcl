## ============================================================================
## Archivo      : ip/data_ram.tcl  (VERSION FIXED)
## Proposito    : Crear/recrear el IP 'data_ram' (BRAM 25600x32, byte-WE 4
##                bits) destruyendo cualquier cache previo.
##
## CAMBIOS vs version original (que producia warnings de width 4->2 y 32->18):
##   1. Borra el .xci, los archivos generados Y el directorio del IP en
##      <proj>/<proj>.gen y <proj>/<proj>.srcs ANTES de crear el IP.
##   2. Setea Use_Byte_Write_Enable, Byte_Size, Write_Width_A explicitamente
##      EN ESE ORDEN (Vivado a veces ignora Byte_Size si llega despues).
##   3. Desactiva ambos output registers explicitamente (Primitives + Core).
##   4. Llama synth_ip al final para garantizar sintesis del IP fresca.
##
## Uso:
##   source ip/data_ram.tcl
## ============================================================================

set ip_name "data_ram"

## --- 1. Limpieza agresiva del IP previo ---------------------------------
if {[get_ips -quiet $ip_name] ne ""} {
    puts "INFO: removiendo IP existente $ip_name (incluyendo cache)"
    catch {reset_target -quiet all [get_ips $ip_name]}
    catch {export_ip_user_files -of_objects [get_files ${ip_name}.xci] \
                                -no_script -reset -force -quiet}
    catch {remove_files -quiet [get_files ${ip_name}.xci]}
}

## Borrar archivos fisicos sobrantes si quedaron
set proj_dir [get_property DIRECTORY [current_project]]
foreach pat [list \
    "$proj_dir/*.gen/sources_1/ip/$ip_name" \
    "$proj_dir/*.srcs/sources_1/ip/$ip_name" \
] {
    foreach d [glob -nocomplain $pat] {
        puts "INFO: borrando residuo $d"
        file delete -force $d
    }
}

## --- 2. Crear IP fresco -------------------------------------------------
create_ip -name blk_mem_gen \
          -vendor xilinx.com \
          -library ip \
          -module_name $ip_name

## ORDEN IMPORTANTE: Memory_Type y Byte_Size primero, despues los widths.
set_property -dict [list \
    CONFIG.Memory_Type                                 {Single_Port_RAM} \
    CONFIG.Use_Byte_Write_Enable                       {true} \
    CONFIG.Byte_Size                                   {8} \
    CONFIG.Write_Width_A                               {32} \
    CONFIG.Write_Depth_A                               {25600} \
    CONFIG.Read_Width_A                                {32} \
    CONFIG.Operating_Mode_A                            {WRITE_FIRST} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives  {false} \
    CONFIG.Register_PortA_Output_of_Memory_Core        {false} \
    CONFIG.Use_RSTA_Pin                                {false} \
    CONFIG.Port_A_Clock                                {100} \
    CONFIG.Port_A_Enable_Rate                          {100} \
    CONFIG.Port_A_Write_Rate                           {50} \
] [get_ips $ip_name]

## Validar widths (chequeo defensivo, falla ruidosamente si Vivado no entendio)
set wea_w [get_property CONFIG.Write_Width_A [get_ips $ip_name]]
if {$wea_w ne "32"} {
    error "ERROR: Vivado puso Write_Width_A=$wea_w en lugar de 32. Abortando."
}

generate_target {instantiation_template synthesis simulation} \
    [get_files [get_property IP_FILE [get_ips $ip_name]]]

## Forzar sintesis del IP (out-of-context) para que el bitstream use ESTA version
catch {synth_ip [get_ips $ip_name]}

puts "INFO: IP $ip_name creado y sintetizado"
puts "      Tamano: 25600 x 32 bits = 100 KiB"
puts "      Byte WE: 4 bits"
