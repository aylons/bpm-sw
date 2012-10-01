---------------------------------------------------------------------------------------
-- Title          : Wishbone slave core for FMC ADC/DAC interface registers
---------------------------------------------------------------------------------------
-- File           : wb_fmc150_port.vhd
-- Author         : auto-generated by wbgen2 from xfmc150.wb
-- Created        : Mon Oct  1 15:20:18 2012
-- Standard       : VHDL'87
---------------------------------------------------------------------------------------
-- THIS FILE WAS GENERATED BY wbgen2 FROM SOURCE FILE xfmc150.wb
-- DO NOT HAND-EDIT UNLESS IT'S ABSOLUTELY NECESSARY!
---------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fmc150_wbgen2_pkg.all;


entity wb_fmc150_port is
  port (
    rst_n_i                                  : in     std_logic;
    clk_sys_i                                : in     std_logic;
    wb_adr_i                                 : in     std_logic_vector(2 downto 0);
    wb_dat_i                                 : in     std_logic_vector(31 downto 0);
    wb_dat_o                                 : out    std_logic_vector(31 downto 0);
    wb_cyc_i                                 : in     std_logic;
    wb_sel_i                                 : in     std_logic_vector(3 downto 0);
    wb_stb_i                                 : in     std_logic;
    wb_we_i                                  : in     std_logic;
    wb_ack_o                                 : out    std_logic;
    wb_stall_o                               : out    std_logic;
    clk_100Mhz                               : in     std_logic;
    regs_i                                   : in     t_fmc150_in_registers;
    regs_o                                   : out    t_fmc150_out_registers
  );
end wb_fmc150_port;

architecture syn of wb_fmc150_port is

signal fmc150_flgs_pulse_int                    : std_logic      ;
signal fmc150_flgs_pulse_int_delay              : std_logic      ;
signal fmc150_flgs_pulse_sync0                  : std_logic      ;
signal fmc150_flgs_pulse_sync1                  : std_logic      ;
signal fmc150_flgs_pulse_sync2                  : std_logic      ;
signal fmc150_flgs_in_spi_rw_int                : std_logic      ;
signal fmc150_flgs_in_ext_clk_int               : std_logic      ;
signal fmc150_addr_int                          : std_logic_vector(15 downto 0);
signal fmc150_data_in_int                       : std_logic_vector(31 downto 0);
signal fmc150_cs_cdce72010_int                  : std_logic      ;
signal fmc150_cs_ads62p49_int                   : std_logic      ;
signal fmc150_cs_dac3283_int                    : std_logic      ;
signal fmc150_cs_amc7823_int                    : std_logic      ;
signal fmc150_adc_dly_str_int                   : std_logic_vector(4 downto 0);
signal fmc150_adc_dly_cha_int                   : std_logic_vector(4 downto 0);
signal fmc150_adc_dly_chb_int                   : std_logic_vector(4 downto 0);
signal ack_sreg                                 : std_logic_vector(9 downto 0);
signal rddata_reg                               : std_logic_vector(31 downto 0);
signal wrdata_reg                               : std_logic_vector(31 downto 0);
signal bwsel_reg                                : std_logic_vector(3 downto 0);
signal rwaddr_reg                               : std_logic_vector(2 downto 0);
signal ack_in_progress                          : std_logic      ;
signal wr_int                                   : std_logic      ;
signal rd_int                                   : std_logic      ;
signal allones                                  : std_logic_vector(31 downto 0);
signal allzeros                                 : std_logic_vector(31 downto 0);

begin
-- Some internal signals assignments. For (foreseen) compatibility with other bus standards.
  wrdata_reg <= wb_dat_i;
  bwsel_reg <= wb_sel_i;
  rd_int <= wb_cyc_i and (wb_stb_i and (not wb_we_i));
  wr_int <= wb_cyc_i and (wb_stb_i and wb_we_i);
  allones <= (others => '1');
  allzeros <= (others => '0');
-- 
-- Main register bank access process.
  process (clk_sys_i, rst_n_i)
  begin
    if (rst_n_i = '0') then 
      ack_sreg <= "0000000000";
      ack_in_progress <= '0';
      rddata_reg <= "00000000000000000000000000000000";
      fmc150_flgs_pulse_int <= '0';
      fmc150_flgs_pulse_int_delay <= '0';
      fmc150_flgs_in_spi_rw_int <= '0';
      fmc150_flgs_in_ext_clk_int <= '0';
      fmc150_addr_int <= "0000000000000000";
      fmc150_data_in_int <= "00000000000000000000000000000000";
      fmc150_cs_cdce72010_int <= '0';
      fmc150_cs_ads62p49_int <= '0';
      fmc150_cs_dac3283_int <= '0';
      fmc150_cs_amc7823_int <= '0';
      fmc150_adc_dly_str_int <= "00000";
      fmc150_adc_dly_cha_int <= "00000";
      fmc150_adc_dly_chb_int <= "00000";
    elsif rising_edge(clk_sys_i) then
-- advance the ACK generator shift register
      ack_sreg(8 downto 0) <= ack_sreg(9 downto 1);
      ack_sreg(9) <= '0';
      if (ack_in_progress = '1') then
        if (ack_sreg(0) = '1') then
          ack_in_progress <= '0';
        else
          fmc150_flgs_pulse_int <= fmc150_flgs_pulse_int_delay;
          fmc150_flgs_pulse_int_delay <= '0';
        end if;
      else
        if ((wb_cyc_i = '1') and (wb_stb_i = '1')) then
          case rwaddr_reg(2 downto 0) is
          when "000" => 
            if (wb_we_i = '1') then
              fmc150_flgs_pulse_int <= wrdata_reg(0);
              fmc150_flgs_pulse_int_delay <= wrdata_reg(0);
            end if;
            rddata_reg(0) <= 'X';
            rddata_reg(1) <= 'X';
            rddata_reg(2) <= 'X';
            rddata_reg(3) <= 'X';
            rddata_reg(4) <= 'X';
            rddata_reg(5) <= 'X';
            rddata_reg(6) <= 'X';
            rddata_reg(7) <= 'X';
            rddata_reg(8) <= 'X';
            rddata_reg(9) <= 'X';
            rddata_reg(10) <= 'X';
            rddata_reg(11) <= 'X';
            rddata_reg(12) <= 'X';
            rddata_reg(13) <= 'X';
            rddata_reg(14) <= 'X';
            rddata_reg(15) <= 'X';
            rddata_reg(16) <= 'X';
            rddata_reg(17) <= 'X';
            rddata_reg(18) <= 'X';
            rddata_reg(19) <= 'X';
            rddata_reg(20) <= 'X';
            rddata_reg(21) <= 'X';
            rddata_reg(22) <= 'X';
            rddata_reg(23) <= 'X';
            rddata_reg(24) <= 'X';
            rddata_reg(25) <= 'X';
            rddata_reg(26) <= 'X';
            rddata_reg(27) <= 'X';
            rddata_reg(28) <= 'X';
            rddata_reg(29) <= 'X';
            rddata_reg(30) <= 'X';
            rddata_reg(31) <= 'X';
            ack_sreg(4) <= '1';
            ack_in_progress <= '1';
          when "001" => 
            if (wb_we_i = '1') then
              fmc150_flgs_in_spi_rw_int <= wrdata_reg(0);
              fmc150_flgs_in_ext_clk_int <= wrdata_reg(1);
            end if;
            rddata_reg(0) <= fmc150_flgs_in_spi_rw_int;
            rddata_reg(1) <= fmc150_flgs_in_ext_clk_int;
            rddata_reg(2) <= 'X';
            rddata_reg(3) <= 'X';
            rddata_reg(4) <= 'X';
            rddata_reg(5) <= 'X';
            rddata_reg(6) <= 'X';
            rddata_reg(7) <= 'X';
            rddata_reg(8) <= 'X';
            rddata_reg(9) <= 'X';
            rddata_reg(10) <= 'X';
            rddata_reg(11) <= 'X';
            rddata_reg(12) <= 'X';
            rddata_reg(13) <= 'X';
            rddata_reg(14) <= 'X';
            rddata_reg(15) <= 'X';
            rddata_reg(16) <= 'X';
            rddata_reg(17) <= 'X';
            rddata_reg(18) <= 'X';
            rddata_reg(19) <= 'X';
            rddata_reg(20) <= 'X';
            rddata_reg(21) <= 'X';
            rddata_reg(22) <= 'X';
            rddata_reg(23) <= 'X';
            rddata_reg(24) <= 'X';
            rddata_reg(25) <= 'X';
            rddata_reg(26) <= 'X';
            rddata_reg(27) <= 'X';
            rddata_reg(28) <= 'X';
            rddata_reg(29) <= 'X';
            rddata_reg(30) <= 'X';
            rddata_reg(31) <= 'X';
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "010" => 
            if (wb_we_i = '1') then
              fmc150_addr_int <= wrdata_reg(15 downto 0);
            end if;
            rddata_reg(15 downto 0) <= fmc150_addr_int;
            rddata_reg(16) <= 'X';
            rddata_reg(17) <= 'X';
            rddata_reg(18) <= 'X';
            rddata_reg(19) <= 'X';
            rddata_reg(20) <= 'X';
            rddata_reg(21) <= 'X';
            rddata_reg(22) <= 'X';
            rddata_reg(23) <= 'X';
            rddata_reg(24) <= 'X';
            rddata_reg(25) <= 'X';
            rddata_reg(26) <= 'X';
            rddata_reg(27) <= 'X';
            rddata_reg(28) <= 'X';
            rddata_reg(29) <= 'X';
            rddata_reg(30) <= 'X';
            rddata_reg(31) <= 'X';
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "011" => 
            if (wb_we_i = '1') then
              fmc150_data_in_int <= wrdata_reg(31 downto 0);
            end if;
            rddata_reg(31 downto 0) <= fmc150_data_in_int;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "100" => 
            if (wb_we_i = '1') then
              fmc150_cs_cdce72010_int <= wrdata_reg(0);
              fmc150_cs_ads62p49_int <= wrdata_reg(1);
              fmc150_cs_dac3283_int <= wrdata_reg(2);
              fmc150_cs_amc7823_int <= wrdata_reg(3);
            end if;
            rddata_reg(0) <= fmc150_cs_cdce72010_int;
            rddata_reg(1) <= fmc150_cs_ads62p49_int;
            rddata_reg(2) <= fmc150_cs_dac3283_int;
            rddata_reg(3) <= fmc150_cs_amc7823_int;
            rddata_reg(4) <= 'X';
            rddata_reg(5) <= 'X';
            rddata_reg(6) <= 'X';
            rddata_reg(7) <= 'X';
            rddata_reg(8) <= 'X';
            rddata_reg(9) <= 'X';
            rddata_reg(10) <= 'X';
            rddata_reg(11) <= 'X';
            rddata_reg(12) <= 'X';
            rddata_reg(13) <= 'X';
            rddata_reg(14) <= 'X';
            rddata_reg(15) <= 'X';
            rddata_reg(16) <= 'X';
            rddata_reg(17) <= 'X';
            rddata_reg(18) <= 'X';
            rddata_reg(19) <= 'X';
            rddata_reg(20) <= 'X';
            rddata_reg(21) <= 'X';
            rddata_reg(22) <= 'X';
            rddata_reg(23) <= 'X';
            rddata_reg(24) <= 'X';
            rddata_reg(25) <= 'X';
            rddata_reg(26) <= 'X';
            rddata_reg(27) <= 'X';
            rddata_reg(28) <= 'X';
            rddata_reg(29) <= 'X';
            rddata_reg(30) <= 'X';
            rddata_reg(31) <= 'X';
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "101" => 
            if (wb_we_i = '1') then
              fmc150_adc_dly_str_int <= wrdata_reg(4 downto 0);
              fmc150_adc_dly_cha_int <= wrdata_reg(12 downto 8);
              fmc150_adc_dly_chb_int <= wrdata_reg(20 downto 16);
            end if;
            rddata_reg(4 downto 0) <= fmc150_adc_dly_str_int;
            rddata_reg(12 downto 8) <= fmc150_adc_dly_cha_int;
            rddata_reg(20 downto 16) <= fmc150_adc_dly_chb_int;
            rddata_reg(5) <= 'X';
            rddata_reg(6) <= 'X';
            rddata_reg(7) <= 'X';
            rddata_reg(13) <= 'X';
            rddata_reg(14) <= 'X';
            rddata_reg(15) <= 'X';
            rddata_reg(21) <= 'X';
            rddata_reg(22) <= 'X';
            rddata_reg(23) <= 'X';
            rddata_reg(24) <= 'X';
            rddata_reg(25) <= 'X';
            rddata_reg(26) <= 'X';
            rddata_reg(27) <= 'X';
            rddata_reg(28) <= 'X';
            rddata_reg(29) <= 'X';
            rddata_reg(30) <= 'X';
            rddata_reg(31) <= 'X';
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "110" => 
            if (wb_we_i = '1') then
            end if;
            rddata_reg(31 downto 0) <= regs_i.data_out_i;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "111" => 
            if (wb_we_i = '1') then
            end if;
            rddata_reg(0) <= regs_i.flgs_out_spi_busy_i;
            rddata_reg(1) <= regs_i.flgs_out_pll_status_i;
            rddata_reg(2) <= regs_i.flgs_out_adc_clk_locked_i;
            rddata_reg(3) <= regs_i.flgs_out_fmc_prst_i;
            rddata_reg(4) <= 'X';
            rddata_reg(5) <= 'X';
            rddata_reg(6) <= 'X';
            rddata_reg(7) <= 'X';
            rddata_reg(8) <= 'X';
            rddata_reg(9) <= 'X';
            rddata_reg(10) <= 'X';
            rddata_reg(11) <= 'X';
            rddata_reg(12) <= 'X';
            rddata_reg(13) <= 'X';
            rddata_reg(14) <= 'X';
            rddata_reg(15) <= 'X';
            rddata_reg(16) <= 'X';
            rddata_reg(17) <= 'X';
            rddata_reg(18) <= 'X';
            rddata_reg(19) <= 'X';
            rddata_reg(20) <= 'X';
            rddata_reg(21) <= 'X';
            rddata_reg(22) <= 'X';
            rddata_reg(23) <= 'X';
            rddata_reg(24) <= 'X';
            rddata_reg(25) <= 'X';
            rddata_reg(26) <= 'X';
            rddata_reg(27) <= 'X';
            rddata_reg(28) <= 'X';
            rddata_reg(29) <= 'X';
            rddata_reg(30) <= 'X';
            rddata_reg(31) <= 'X';
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when others =>
-- prevent the slave from hanging the bus on invalid address
            ack_in_progress <= '1';
            ack_sreg(0) <= '1';
          end case;
        end if;
      end if;
    end if;
  end process;
  
  
-- Drive the data output bus
  wb_dat_o <= rddata_reg;
-- Update ADC delay
  process (clk_100Mhz, rst_n_i)
  begin
    if (rst_n_i = '0') then 
      regs_o.flgs_pulse_o <= '0';
      fmc150_flgs_pulse_sync0 <= '0';
      fmc150_flgs_pulse_sync1 <= '0';
      fmc150_flgs_pulse_sync2 <= '0';
    elsif rising_edge(clk_100Mhz) then
      fmc150_flgs_pulse_sync0 <= fmc150_flgs_pulse_int;
      fmc150_flgs_pulse_sync1 <= fmc150_flgs_pulse_sync0;
      fmc150_flgs_pulse_sync2 <= fmc150_flgs_pulse_sync1;
      regs_o.flgs_pulse_o <= fmc150_flgs_pulse_sync2 and (not fmc150_flgs_pulse_sync1);
    end if;
  end process;
  
  
-- SPI Read/Write flag
  regs_o.flgs_in_spi_rw_o <= fmc150_flgs_in_spi_rw_int;
-- External Clock for ADC
  regs_o.flgs_in_ext_clk_o <= fmc150_flgs_in_ext_clk_int;
-- SPI address
  regs_o.addr_o <= fmc150_addr_int;
-- Data In for FMC150
  regs_o.data_in_o <= fmc150_data_in_int;
-- Chipselect for cdce72010
  regs_o.cs_cdce72010_o <= fmc150_cs_cdce72010_int;
-- Chipselect for ads62p49
  regs_o.cs_ads62p49_o <= fmc150_cs_ads62p49_int;
-- Chipselect for dac3283
  regs_o.cs_dac3283_o <= fmc150_cs_dac3283_int;
-- Chipselect for amc7823
  regs_o.cs_amc7823_o <= fmc150_cs_amc7823_int;
-- ADC Strobe delay
  regs_o.adc_dly_str_o <= fmc150_adc_dly_str_int;
-- ADC Channel A delay
  regs_o.adc_dly_cha_o <= fmc150_adc_dly_cha_int;
-- ADC Strobe delay
  regs_o.adc_dly_chb_o <= fmc150_adc_dly_chb_int;
-- Data out from FMC150
-- SPI Busy
-- CDCE72010 PLL Status
-- FPGA ADC clock locked
-- FMC present
  rwaddr_reg <= wb_adr_i;
  wb_stall_o <= (not ack_sreg(0)) and (wb_stb_i and wb_cyc_i);
-- ACK signal generation. Just pass the LSB of ACK counter.
  wb_ack_o <= ack_sreg(0);
end syn;
