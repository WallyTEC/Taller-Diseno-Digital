## ============================================================================
## Archivo      : ip/rom_program.tcl
## Autor        : WallyCR
## Fecha        : 20 de abril de 2026
## Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
## Descripción  : Crea el IP Block Memory Generator 'rom_program' en el
##                proyecto Vivado activo. Single Port ROM, 512×32 bits,
##                inicializada desde main.coe.
##
## Uso:
##   En la consola Tcl de Vivado (con el proyecto abierto):
##     source ip/rom_program.tcl
##
##   El script busca main.coe en varias rutas comunes; si no lo encuentra,
##   se puede pasar la ruta explícita antes del source:
##     set coe_file "/ruta/absoluta/a/main.coe"
##     source ip/rom_program.tcl
## ============================================================================

set ip_name "rom_program"

## ----------------------------------------------------------------------------
## Búsqueda del archivo .coe
## ----------------------------------------------------------------------------
if {![info exists coe_file] || $coe_file eq ""} {
    # Ruta 1: relativa al cwd actual (si pwd está en el repo)
    set candidates [list \
        [file normalize "./sw/build/main.coe"] \
        [file normalize "../sw/build/main.coe"] \
        [file normalize "[get_property DIRECTORY [current_project]]/../sw/build/main.coe"] \
        [file normalize "[get_property DIRECTORY [current_project]]/../../sw/build/main.coe"] \
    ]
    set coe_file ""
    foreach c $candidates {
        if {[file exists $c]} {
            set coe_file $c
            puts "INFO: main.coe encontrado en $c"
            break
        }
    }
}

if {$coe_file eq "" || ![file exists $coe_file]} {
    puts "WARNING: no se encontró main.coe en ninguna ruta conocida."
    puts "         Rutas probadas:"
    foreach c $candidates { puts "           - $c" }
    puts ""
    puts "         Continuando con ROM inicializada en ceros."
    puts "         Para usar un .coe específico, corré:"
    puts "           set coe_file \"/ruta/absoluta/a/main.coe\""
    puts "           source ip/rom_program.tcl"
    set use_init 0
} else {
    puts "INFO: usando $coe_file para inicializar la ROM"
    set use_init 1
}

## ----------------------------------------------------------------------------
## Limpieza de IP previo (si existe)
## ----------------------------------------------------------------------------
if {[get_ips -quiet $ip_name] ne ""} {
    puts "INFO: removiendo IP existente $ip_name"
    export_ip_user_files -of_objects [get_files ${ip_name}.xci] -no_script -reset -force -quiet
    remove_files -quiet [get_files ${ip_name}.xci]
}

## ----------------------------------------------------------------------------
## Creación del IP
## ----------------------------------------------------------------------------
create_ip -name blk_mem_gen \
          -vendor xilinx.com \
          -library ip \
          -module_name $ip_name

set base_config [list \
    CONFIG.Memory_Type           {Single_Port_ROM} \
    CONFIG.Use_Byte_Write_Enable {false} \
    CONFIG.Write_Width_A         {32} \
    CONFIG.Write_Depth_A         {512} \
    CONFIG.Read_Width_A          {32} \
    CONFIG.Operating_Mode_A      {READ_FIRST} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Use_RSTA_Pin          {false} \
    CONFIG.Port_A_Clock          {100} \
    CONFIG.Port_A_Enable_Rate    {100} \
]

if {$use_init} {
    lappend base_config \
        CONFIG.Load_Init_File {true} \
        CONFIG.Coe_File       $coe_file
}

set_property -dict $base_config [get_ips $ip_name]

generate_target {instantiation_template synthesis simulation} \
    [get_files [get_property IP_FILE [get_ips $ip_name]]]

puts "INFO: IP $ip_name creado correctamente"
puts "      Tipo:      Single Port ROM"
puts "      Tamaño:    512 × 32 bits = 2 KiB"
if {$use_init} {
    puts "      Init file: $coe_file"
} else {
    puts "      Init file: (ninguno, ROM en ceros)"
}

## Limpiar variable global para que no moleste en siguientes sources
unset -nocomplain coe_file
