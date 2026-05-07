## ============================================================================
## Archivo      : ip/rom_program.tcl  (VERSION FIXED)
## Proposito    : Crear/recrear el IP 'rom_program' (BRAM 512x32 ROM, init
##                desde main.coe). Destruye cualquier cache previo.
##
## CAMBIOS vs version original:
##   1. Limpieza agresiva del IP previo (incluido directorio fisico).
##   2. Setea explicitamente Use_RSTA_Pin=false y ambos output registers en
##      false (latencia 1 ciclo, sin reset, sin enable-pin manual).
##   3. Validacion defensiva del Memory_Type final.
##
## Uso:
##   set coe_file "/ruta/absoluta/a/main.coe"   ;# opcional, autodetecta
##   source ip/rom_program.tcl
## ============================================================================

set ip_name "rom_program"

## --- 1. Buscar el .coe -------------------------------------------------
if {![info exists coe_file] || $coe_file eq ""} {
    set candidates [list \
        [file normalize "./sw/build/main.coe"] \
        [file normalize "../sw/build/main.coe"] \
        [file normalize "[get_property DIRECTORY [current_project]]/../sw/build/main.coe"] \
        [file normalize "[get_property DIRECTORY [current_project]]/../../sw/build/main.coe"] \
    ]
    set coe_file ""
    foreach c $candidates {
        if {[file exists $c]} { set coe_file $c ; break }
    }
}

if {$coe_file eq "" || ![file exists $coe_file]} {
    puts "WARNING: main.coe no encontrado. ROM se inicializa en ceros."
    set use_init 0
} else {
    puts "INFO: usando $coe_file"
    set use_init 1
}

## --- 2. Limpieza agresiva del IP previo --------------------------------
if {[get_ips -quiet $ip_name] ne ""} {
    puts "INFO: removiendo IP existente $ip_name (incluyendo cache)"
    catch {reset_target -quiet all [get_ips $ip_name]}
    catch {export_ip_user_files -of_objects [get_files ${ip_name}.xci] \
                                -no_script -reset -force -quiet}
    catch {remove_files -quiet [get_files ${ip_name}.xci]}
}

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

## --- 3. Crear IP fresco ------------------------------------------------
create_ip -name blk_mem_gen \
          -vendor xilinx.com \
          -library ip \
          -module_name $ip_name

set base_config [list \
    CONFIG.Memory_Type                                 {Single_Port_ROM} \
    CONFIG.Use_Byte_Write_Enable                       {false} \
    CONFIG.Write_Width_A                               {32} \
    CONFIG.Write_Depth_A                               {512} \
    CONFIG.Read_Width_A                                {32} \
    CONFIG.Operating_Mode_A                            {READ_FIRST} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives  {false} \
    CONFIG.Register_PortA_Output_of_Memory_Core        {false} \
    CONFIG.Use_RSTA_Pin                                {false} \
    CONFIG.Port_A_Clock                                {100} \
    CONFIG.Port_A_Enable_Rate                          {100} \
]

if {$use_init} {
    lappend base_config \
        CONFIG.Load_Init_File {true} \
        CONFIG.Coe_File       $coe_file
}

set_property -dict $base_config [get_ips $ip_name]

## Validacion defensiva
set mt [get_property CONFIG.Memory_Type [get_ips $ip_name]]
if {$mt ne "Single_Port_ROM"} {
    error "ERROR: Memory_Type quedo en $mt en lugar de Single_Port_ROM"
}

generate_target {instantiation_template synthesis simulation} \
    [get_files [get_property IP_FILE [get_ips $ip_name]]]
catch {synth_ip [get_ips $ip_name]}

puts "INFO: IP $ip_name creado y sintetizado"
puts "      Tamano: 512 x 32 bits = 2 KiB"
if {$use_init} { puts "      Init: $coe_file" }

unset -nocomplain coe_file
