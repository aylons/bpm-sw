------------------------------------------------------------------------------
-- Title      : Wishbone FMC516 ADC Interface
------------------------------------------------------------------------------
-- Author     : Lucas Maziero Russo
-- Company    : CNPEM LNLS-DIG
-- Created    : 2012-17-10
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: General definitions package or the FMC516 ADC board from Curtis Wright.
-------------------------------------------------------------------------------
-- Copyright (c) 2012 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2012-29-10  1.0      lucas.russo        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.wishbone_pkg.all;
use work.wb_stream_pkg.all;

package fmc516_pkg is
  --------------------------------------------------------------------
  -- Constants
  --------------------------------------------------------------------
  -- constants for the fmc516_adc_iface
  constant c_num_adc_channels : natural := 4;
  constant c_num_adc_bits : natural := 16;
  --------------------------------------------------------------------
  -- Generic definitions
  --------------------------------------------------------------------
  type t_real_array is array (natural range <>) of real;
  type t_natural_array is array (natural range <>) of natural;

  --------------------------------------------------------------------
  -- Specific definitions
  --------------------------------------------------------------------
  -- types for the fmc516_adc_iface
  type t_adc_in is record
    adc_clk : std_logic;
    adc_rst_n : std_logic;
    adc_data : std_logic_vector(c_num_adc_bits/2 - 1 downto 0);
  end record;

  type t_adc_in_array is array (natural range <>) of t_adc_in;

  type t_adc_dly is record
    adc_clk_dly_pulse : std_logic;
    adc_clk_dly_val : std_logic_vector(4 downto 0);
    adc_data_dly_pulse : std_logic;
    adc_data_dly_val : std_logic_vector(4 downto 0);
  end record;

  type t_adc_dly_array is array (natural range <>) of t_adc_dly;

  type t_adc_out is record
    adc_clk : std_logic;
    adc_clk2x : std_logic;
    adc_data : std_logic_vector(c_num_adc_bits-1 downto 0);
    adc_data_valid : std_logic;
  end record;

  type t_adc_out_array is array (natural range <>) of t_adc_out;

  -- types for fmc516_adc_iface generic definitions
  subtype t_default_adc_dly is t_natural_array(c_num_adc_channels-1 downto 0);
  subtype t_clk_values_array is t_real_array(c_num_adc_channels-1 downto 0);
  subtype t_clk_use_chain is std_logic_vector(c_num_adc_channels-1 downto 0);
  subtype t_data_use_chain is std_logic_vector(c_num_adc_channels-1 downto 0);

  -- Constant default values.
  constant default_data_dly : t_default_adc_dly := (others => 5);
  constant default_clk_dly : t_default_adc_dly := (others => 0);
  constant default_adc_clk_period_values : t_clk_values_array :=
    (0.0, 0.0, 0.0, 4.0);
  constant default_clk_use_chain : t_clk_use_chain :=
    ("0001");
  constant default_data_use_chain : t_data_use_chain :=
    ("1111");

  -- dummy values for fmc516_adc_iface generic definitions
  -- Warning: all clocks are null here! Should be modified
  constant dummy_clks : t_clk_values_array := (others => 0.0);
  constant dummy_clk_use_chain : t_clk_use_chain := (others => '0');
  constant dummy_data_use_chain : t_data_use_chain := (others => '0');
  constant dummy_default_dly : t_default_adc_dly := (others => 0);

  -- SDB for internal FMCC516 layout. More general cores have its SDB structure
  -- defined indes custom_wishbone_pkg file.
    -- FMC516 Interface
  constant c_xwb_fmc516_regs_sdb : t_sdb_device := (
    abi_class     => x"0000",                 -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"00",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"4",                     -- 32-bit port granularity (0100)
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000000FF",
    product => (
    vendor_id     => x"1000000000001215",     -- LNLS
    device_id     => x"27b95341",
    version       => x"00000001",
    date          => x"20121124",
    name          => "LNLS_FMC516_REGS   ")));

    -- Type for f_chain_intercon function
    type t_chain_intercon is array (natural range <>) of integer;

    -- Functions
    function f_chain_intercon(clock_chains : std_logic_vector; data_chains : std_logic_vector)
      return t_chain_intercon;
end fmc516_pkg;


package body fmc516_pkg is

  -- Fill out the intercon vector. This vector has c_num_data_chains positions
  -- and means which clock is connected for each data chain (position index): -1,
  -- means not to use this data chain; 0..c_num_clock_chains, means the clock
  -- driving this data chain.
  --
  -- The policy for attributing a data chain to a clock chain is simply clocking
  -- the data chain index that is less or equal than the next usable clock index
  -- in the clock chain. If there are remaining data chain to be clocked using the
  -- above logic, the default is to connect them to the last available clock in
  -- the clock chain.
  function f_chain_intercon(clock_chains : std_logic_vector; data_chains : std_logic_vector)
    return t_chain_intercon
  is
    constant c_num_chains : natural := clock_chains'length;
    variable intercon : t_chain_intercon(c_num_chains-1 downto 0) := (others => -1);
    variable data_chain_idx : natural := 0;
    variable i : natural := 0;
    variable j : natural := 0;
    variable k : natural := 0;
  begin
    -- Check for the sizes
    assert (clock_chains'length = data_chains'length) report
      "Vectors clocks and data have different sizes" severity failure;

    --for i in 0 to c_num_clock_chains-1 loop
    while i < c_num_chains loop
      if clock_chains(i) = '1' then
        --for j in data_chain_idx to i loop
        j := data_chain_idx;
        while j <= i loop
          if data_chains(j) = '1' then
            intercon(j) := i;
          end if;
          j := j + 1;
        end loop;
        data_chain_idx := i+1;
      end if;
      i := i + 1;
    end loop;

    -- If there are remaining data chains unclocked, attribute
    -- them to the last usable clock
    for i in data_chain_idx to c_num_chains-1 loop
      if data_chains(i) = '1' then
        intercon(i) := data_chain_idx-1;
      end if;
    end loop;

    -- Print the intercon vector
    for k in 0 to c_num_chains-1 loop
      report "[ intercon(" & integer'image(k) & ") = " &
          Integer'image(intercon(k)) & " ]"
      severity note;
    end loop;

    return intercon;
  end f_chain_intercon;

  end fmc516_pkg;
