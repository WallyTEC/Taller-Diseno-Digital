## ============================================================================
## Archivo      : ip/data_ram.tcl
## Autor        : WallyCR
## Fecha        : 20 de abril de 2026
## Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
## Descripción  : Crea el IP Block Memory Generator 'data_ram'.
##                Single Port RAM, 25 600 × 32 bits = 100 KiB, byte-write-
##                enable de 4 bits.
##
##                NOTA: el puerto ENA siempre está presente cuando se
##                habilita byte-write-enable; no hace falta (ni existe)
##                el parámetro Use_ENA_Pin en versiones recientes del IP.
##
## Uso:
##   source ip/data_ram.tcl
## ============================================================================

set ip_name "data_ram"

if {[get_ips -quiet $ip_name] ne ""} {
    puts "INFO: removiendo IP existente $ip_name"
    export_ip_user_files -of_objects [get_files ${ip_name}.xci] -no_script -reset -force -quiet
    remove_files -quiet [get_files ${ip_name}.xci]
}

create_ip -name blk_mem_gen \
          -vendor xilinx.com \
          -library ip \
          -module_name $ip_name

set_property -dict [list \
    CONFIG.Memory_Type           {Single_Port_RAM} \
    CONFIG.Use_Byte_Write_Enable {true} \
    CONFIG.Byte_Size             {8} \
    CONFIG.Write_Width_A         {32} \
    CONFIG.Write_Depth_A         {25600} \
    CONFIG.Read_Width_A          {32} \
    CONFIG.Operating_Mode_A      {WRITE_FIRST} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Use_RSTA_Pin          {false} \
    CONFIG.Port_A_Clock          {100} \
    CONFIG.Port_A_Enable_Rate    {100} \
    CONFIG.Port_A_Write_Rate     {50} \
] [get_ips $ip_name]

generate_target {instantiation_template synthesis simulation} \
    [get_files [get_property IP_FILE [get_ips $ip_name]]]

puts "INFO: IP $ip_name creado correctamente"
puts "      Tipo:      Single Port RAM"
puts "      Tamaño:    25 600 × 32 bits = 100 KiB"
puts "      Byte WE:   sí (4 bits)"
