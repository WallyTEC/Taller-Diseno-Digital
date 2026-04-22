## ============================================================================
## Archivo      : constraints/nexys4ddr.xdc
## Autor        : WallyCR
## Fecha        : 20 de abril de 2026
## Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
## Descripción  : Pin assignments para SoC RISC-V en Digilent Nexys4 DDR
##                (Artix-7 XC7A100T-1CSG324C). Basado en el master XDC
##                oficial de Digilent, con sólo los pines usados por
##                este proyecto descomentados.
##
## Convención: cada pin lleva su standard de I/O (LVCMOS33) y la señal
## del top.sv a la que se conecta.
## ============================================================================

## ----------------------------------------------------------------------------
## Reloj 100 MHz
## ----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk_100mhz_i]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk_100mhz_i]

## ----------------------------------------------------------------------------
## Botones (CPU_RESETN y BTNC/U/D/L/R)
## En la Nexys4 DDR, los 5 botones de la cruz son activos-altos.
## CPU_RESETN (botón rojo dedicado) es activo-bajo. No lo usamos.
## ----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports btnc_i]
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports btnu_i]
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports btnd_i]
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports btnl_i]
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS33} [get_ports btnr_i]

## ----------------------------------------------------------------------------
## Switches (16)
## SW0..SW7  -> bancos LVCMOS33
## SW8..SW15 -> banco LVCMOS18 (importante!)
## ----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN J15  IOSTANDARD LVCMOS33} [get_ports {sw_i[0]}]
set_property -dict {PACKAGE_PIN L16  IOSTANDARD LVCMOS33} [get_ports {sw_i[1]}]
set_property -dict {PACKAGE_PIN M13  IOSTANDARD LVCMOS33} [get_ports {sw_i[2]}]
set_property -dict {PACKAGE_PIN R15  IOSTANDARD LVCMOS33} [get_ports {sw_i[3]}]
set_property -dict {PACKAGE_PIN R17  IOSTANDARD LVCMOS33} [get_ports {sw_i[4]}]
set_property -dict {PACKAGE_PIN T18  IOSTANDARD LVCMOS33} [get_ports {sw_i[5]}]
set_property -dict {PACKAGE_PIN U18  IOSTANDARD LVCMOS33} [get_ports {sw_i[6]}]
set_property -dict {PACKAGE_PIN R13  IOSTANDARD LVCMOS33} [get_ports {sw_i[7]}]
set_property -dict {PACKAGE_PIN T8   IOSTANDARD LVCMOS18} [get_ports {sw_i[8]}]
set_property -dict {PACKAGE_PIN U8   IOSTANDARD LVCMOS18} [get_ports {sw_i[9]}]
set_property -dict {PACKAGE_PIN R16  IOSTANDARD LVCMOS33} [get_ports {sw_i[10]}]
set_property -dict {PACKAGE_PIN T13  IOSTANDARD LVCMOS33} [get_ports {sw_i[11]}]
set_property -dict {PACKAGE_PIN H6   IOSTANDARD LVCMOS33} [get_ports {sw_i[12]}]
set_property -dict {PACKAGE_PIN U12  IOSTANDARD LVCMOS33} [get_ports {sw_i[13]}]
set_property -dict {PACKAGE_PIN U11  IOSTANDARD LVCMOS33} [get_ports {sw_i[14]}]
set_property -dict {PACKAGE_PIN V10  IOSTANDARD LVCMOS33} [get_ports {sw_i[15]}]

## ----------------------------------------------------------------------------
## LEDs (16)
## ----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN H17  IOSTANDARD LVCMOS33} [get_ports {leds_o[0]}]
set_property -dict {PACKAGE_PIN K15  IOSTANDARD LVCMOS33} [get_ports {leds_o[1]}]
set_property -dict {PACKAGE_PIN J13  IOSTANDARD LVCMOS33} [get_ports {leds_o[2]}]
set_property -dict {PACKAGE_PIN N14  IOSTANDARD LVCMOS33} [get_ports {leds_o[3]}]
set_property -dict {PACKAGE_PIN R18  IOSTANDARD LVCMOS33} [get_ports {leds_o[4]}]
set_property -dict {PACKAGE_PIN V17  IOSTANDARD LVCMOS33} [get_ports {leds_o[5]}]
set_property -dict {PACKAGE_PIN U17  IOSTANDARD LVCMOS33} [get_ports {leds_o[6]}]
set_property -dict {PACKAGE_PIN U16  IOSTANDARD LVCMOS33} [get_ports {leds_o[7]}]
set_property -dict {PACKAGE_PIN V16  IOSTANDARD LVCMOS33} [get_ports {leds_o[8]}]
set_property -dict {PACKAGE_PIN T15  IOSTANDARD LVCMOS33} [get_ports {leds_o[9]}]
set_property -dict {PACKAGE_PIN U14  IOSTANDARD LVCMOS33} [get_ports {leds_o[10]}]
set_property -dict {PACKAGE_PIN T16  IOSTANDARD LVCMOS33} [get_ports {leds_o[11]}]
set_property -dict {PACKAGE_PIN V15  IOSTANDARD LVCMOS33} [get_ports {leds_o[12]}]
set_property -dict {PACKAGE_PIN V14  IOSTANDARD LVCMOS33} [get_ports {leds_o[13]}]
set_property -dict {PACKAGE_PIN V12  IOSTANDARD LVCMOS33} [get_ports {leds_o[14]}]
set_property -dict {PACKAGE_PIN V11  IOSTANDARD LVCMOS33} [get_ports {leds_o[15]}]

## ----------------------------------------------------------------------------
## UART USB-Serial (puente USB de la Nexys4 DDR)
## Desde el punto de vista de la FPGA:
##   uart_txd_o = TX hacia el host (la PC ve esto como RX)
##   uart_rxd_i = RX desde el host (la PC ve esto como TX)
## ----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN D4   IOSTANDARD LVCMOS33} [get_ports uart_txd_o]
set_property -dict {PACKAGE_PIN C4   IOSTANDARD LVCMOS33} [get_ports uart_rxd_i]

## ----------------------------------------------------------------------------
## Configuración del bitstream
## ----------------------------------------------------------------------------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
