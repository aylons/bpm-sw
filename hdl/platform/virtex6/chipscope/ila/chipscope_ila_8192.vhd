-------------------------------------------------------------------------------
-- Copyright (c) 2013 Xilinx, Inc.
-- All Rights Reserved
-------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor     : Xilinx
-- \   \   \/     Version    : 13.4
--  \   \         Application: XILINX CORE Generator
--  /   /         Filename   : chipscope_ila_8192.vhd
-- /___/   /\     Timestamp  : Wed Mar 27 17:21:28 BRT 2013
-- \   \  /  \
--  \___\/\___\
--
-- Design Name: VHDL Synthesis Wrapper
-------------------------------------------------------------------------------
-- This wrapper is used to integrate with Project Navigator and PlanAhead

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
ENTITY chipscope_ila_8192 IS
  port (
    CONTROL: inout std_logic_vector(35 downto 0);
    CLK: in std_logic;
    TRIG0: in std_logic_vector(7 downto 0);
    TRIG1: in std_logic_vector(31 downto 0);
    TRIG2: in std_logic_vector(31 downto 0);
    TRIG3: in std_logic_vector(31 downto 0);
    TRIG4: in std_logic_vector(31 downto 0));
END chipscope_ila_8192;

ARCHITECTURE chipscope_ila_8192_a OF chipscope_ila_8192 IS
BEGIN

END chipscope_ila_8192_a;
