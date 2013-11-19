------------------------------------------------------------------------------
-- Title      : BPM Data Acquisition
------------------------------------------------------------------------------
-- Author     : Lucas Maziero Russo
-- Company    : CNPEM LNLS-DIG
-- Created    : 2013-22-10
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: Top Module for the BPM Data Acquisition
--
--              It allows for the following types of acquisition:
--               1) Simple acquisition on request
--               2) Pre-trigger acquisition
--               3) Post-trigger acquisition
--               4) Pre+Post-trigger acquisition
--
--               TODO: fix FIXMEs
--                     do TODOs
--                     implement anti-overflow in main FIFO (acquire until
--                       the requested number of samples or until the FIFO is
--                       full and another valid samples comes in). Report this
--                       to the user through a wishbone register or some other
--                       method
-------------------------------------------------------------------------------
-- Copyright (c) 2013 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2013-22-10  1.0      lucas.russo        Created
-------------------------------------------------------------------------------

-- Based on FMC-ADC-100M (http://www.ohwr.org/projects/fmc-adc-100m14b4cha/repository)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
-- Main Wishbone Definitions
use work.wishbone_pkg.all;
-- General common cores
use work.gencores_pkg.all;
-- Genrams cores
use work.genram_pkg.all;
-- BPM acq core cores
use work.acq_core_pkg.all;
-- BPM FSM Acq Regs
use work.acq_core_wbgen2_pkg.all;
-- DBE wishbone cores
use work.dbe_wishbone_pkg.all;

entity wb_acq_core is
generic
(
  g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
  g_address_granularity                     : t_wishbone_address_granularity := WORD;
  g_data_width                              : natural := 64;
  g_addr_width                              : natural := 32;
  g_ddr_payload_width                       : natural := 256;
  g_ddr_addr_width                          : natural := 32;
  g_multishot_ram_size                      : natural := 2048;
  g_fifo_fc_size                            : natural := 64;
  g_sim_readback                            : boolean := false
);
port
(
  fs_clk_i                                  : in std_logic;
  fs_ce_i                                   : in std_logic;
  fs_rst_n_i                                : in std_logic;

  sys_clk_i                                 : in std_logic;
  sys_rst_n_i                               : in std_logic;

  ext_clk_i                                 : in std_logic;
  ext_rst_n_i                               : in std_logic;

  -----------------------------
  -- Wishbone Control Interface signals
  -----------------------------

  wb_adr_i                                  : in  std_logic_vector(c_wishbone_address_width-1 downto 0) := (others => '0');
  wb_dat_i                                  : in  std_logic_vector(c_wishbone_data_width-1 downto 0) := (others => '0');
  wb_dat_o                                  : out std_logic_vector(c_wishbone_data_width-1 downto 0);
  wb_sel_i                                  : in  std_logic_vector(c_wishbone_data_width/8-1 downto 0) := (others => '0');
  wb_we_i                                   : in  std_logic := '0';
  wb_cyc_i                                  : in  std_logic := '0';
  wb_stb_i                                  : in  std_logic := '0';
  wb_ack_o                                  : out std_logic;
  wb_err_o                                  : out std_logic;
  wb_rty_o                                  : out std_logic;
  wb_stall_o                                : out std_logic;

  -----------------------------
  -- External Interface
  -----------------------------
  data_i                                    : in  std_logic_vector(g_data_width-1 downto 0);
  dvalid_i                                  : in  std_logic := '0';
  ext_trig_i                                : in  std_logic := '0';

  -----------------------------
  -- DRRAM Interface
  -----------------------------
  dpram_dout_o                              : out std_logic_vector(g_data_width-1 downto 0);
  dpram_valid_o                             : out std_logic;

  -----------------------------
  -- External Interface (w/ FLow Control)
  -----------------------------
  ext_dout_o                                : out std_logic_vector(g_data_width-1 downto 0);
  ext_valid_o                               : out std_logic;
  ext_addr_o                                : out std_logic_vector(g_addr_width-1 downto 0);
  ext_sof_o                                 : out std_logic;
  ext_eof_o                                 : out std_logic;
  ext_dreq_o                                : out std_logic; -- for debbuging purposes
  ext_stall_o                               : out std_logic; -- for debbuging purposes

  -----------------------------
  -- DDR3 SDRAM Interface
  -----------------------------
  ui_app_addr_o                             : out std_logic_vector(g_ddr_addr_width-1 downto 0);
  ui_app_cmd_o                              : out std_logic_vector(2 downto 0);
  ui_app_en_o                               : out std_logic;
  ui_app_rdy_i                              : in std_logic;

  ui_app_wdf_data_o                         : out std_logic_vector(g_ddr_payload_width-1 downto 0);
  ui_app_wdf_end_o                          : out std_logic;
  ui_app_wdf_mask_o                         : out std_logic_vector(g_ddr_payload_width/8-1 downto 0);
  ui_app_wdf_wren_o                         : out std_logic;
  ui_app_wdf_rdy_i                          : in std_logic;

  ui_app_rd_data_i                          : in std_logic_vector(g_ddr_payload_width-1 downto 0);
  ui_app_rd_data_end_i                      : in std_logic;
  ui_app_rd_data_valid_i                    : in std_logic;

  ui_app_req_o                              : out std_logic;
  ui_app_gnt_i                              : in std_logic;
  -----------------------------
  -- Debug Interface
  -----------------------------
  dbg_ddr_rb_data_o                         : out std_logic_vector(g_data_width-1 downto 0);
  dbg_ddr_rb_addr_o                         : out std_logic_vector(g_addr_width-1 downto 0);
  dbg_ddr_rb_valid_o                        : out std_logic
);
end wb_acq_core;

architecture rtl of wb_acq_core is

  -----------------------------
  -- General Constants
  -----------------------------
  constant c_acq_samples_size               : natural := 32;
  constant c_dpram_depth                    : integer := f_log2_size(g_multishot_ram_size);
  constant c_periph_addr_size               : natural := 3+3;

  ------------------------------------------------------------------------------
  -- Types declaration
  ------------------------------------------------------------------------------
  --type t_acq_fsm_state is (IDLE, PRE_TRIG, WAIT_TRIG, POST_TRIG, DECR_SHOT);

  -- Registers Signals
  signal regs_in                            : t_acq_core_in_registers;
  signal regs_out                           : t_acq_core_out_registers;

  -- Wishbone slave adapter signals/structures
  signal wb_slv_adp_out                     : t_wishbone_master_out;
  signal wb_slv_adp_in                      : t_wishbone_master_in;
  signal resized_addr                       : std_logic_vector(c_wishbone_address_width-1 downto 0);

  -- Trigger
  signal ext_trig_a                         : std_logic;
  signal ext_trig                           : std_logic;
  signal int_trig                           : std_logic;
  signal int_trig_over_thres                : std_logic;
  signal int_trig_over_thres_d              : std_logic;
  signal int_trig_sel                       : std_logic_vector(1 downto 0);
  signal int_trig_data                      : std_logic_vector(15 downto 0);
  signal int_trig_thres                     : std_logic_vector(15 downto 0);
  signal hw_trig_pol                        : std_logic;
  signal hw_trig                            : std_logic;
  signal hw_trig_t                          : std_logic;
  signal hw_trig_sel                        : std_logic;
  signal hw_trig_en                         : std_logic;
  signal sw_trig                            : std_logic;
  signal sw_trig_t                          : std_logic;
  signal sw_trig_en                         : std_logic;
  signal trig                               : std_logic;
  signal trig_delay                         : std_logic_vector(31 downto 0);
  signal trig_delay_cnt                     : unsigned(31 downto 0);
  signal trig_d                             : std_logic;
  signal trig_align                         : std_logic;

  ---- Acquisition FSM
  --signal acq_fsm_current_state              : t_acq_fsm_state;
  signal acq_fsm_state                      : std_logic_vector(2 downto 0);
  ----signal fsm_cmd                            : std_logic_vector(1 downto 0);
  ----signal fsm_cmd_wr                         : std_logic;
  signal acq_start                          : std_logic;
  signal acq_start_sync_ext                 : std_logic;
  signal acq_now                            : std_logic;
  signal acq_stop                           : std_logic;
  --signal acq_end_p                          : std_logic;
  signal acq_end                            : std_logic;
  signal acq_trig                           : std_logic;
  --signal acq_end                            : std_logic;
  --signal acq_end_d                          : std_logic;
  signal acq_in_pre_trig                    : std_logic;
  signal acq_in_wait_trig                   : std_logic;
  signal acq_in_post_trig                   : std_logic;
  signal samples_wr_en                      : std_logic;
  --
  ---- Pre/Post trigger and shots counters
  signal pre_trig_samples_c                 : unsigned(c_acq_samples_size-1 downto 0);
  signal post_trig_samples_c                : unsigned(c_acq_samples_size-1 downto 0);
  signal shots_nb_c                         : unsigned(15 downto 0);

  signal acq_single_shot                    : std_logic;
  signal acq_ddr3_start_addr_full           : std_logic_vector(31 downto 0); -- full 32-bit address
  signal acq_ddr3_start_addr                : std_logic_vector(g_ddr_addr_width-1 downto 0);

  ----signal pre_trig_value                     : std_logic_vector(31 downto 0);
  --signal pre_trig_cnt                       : unsigned(31 downto 0);
  signal acq_pre_trig_done                  : std_logic;
  signal acq_wait_trig_skip_done            : std_logic;
  ----signal post_trig_value                    : std_logic_vector(31 downto 0);
  --signal post_trig_cnt                      : unsigned(31 downto 0);
  signal acq_post_trig_done                 : std_logic;
  signal samples_cnt                        : unsigned(c_acq_samples_size-1 downto 0);
  ----signal shots_value                        : std_logic_vector(15 downto 0);
  signal shots_cnt                          : unsigned(15 downto 0);
  --signal shots_done                         : std_logic;
  signal shots_decr                         : std_logic;
  --signal single_shot                        : std_logic;
  signal multishot_buffer_sel               : std_logic;

  -- Packet size for ext interface
  signal lmt_acq_pkt_size                   : unsigned(c_acq_samples_size-1 downto 0);
  signal lmt_shots_nb                       : unsigned(15 downto 0);
  signal lmt_valid                          : std_logic;

  -- Multi-shot mode
  signal dpram_addra_cnt                    : unsigned(c_dpram_depth-1 downto 0);
  signal dpram_addra_trig                   : unsigned(c_dpram_depth-1 downto 0);
  signal dpram_addra_post_done              : unsigned(c_dpram_depth-1 downto 0);
  signal dpram_addrb_cnt                    : unsigned(c_dpram_depth-1 downto 0);
  signal dpram_dout                         : std_logic_vector(g_data_width-1 downto 0);
  signal dpram_valid                        : std_logic;

  -- FIFO Flow Control signals
  --signal fifo_fc_trans_done_p               : std_logic;
  signal fifo_fc_req_rst_trans              : std_logic;

  --signal fifo_fc_all_trans_end              : std_logic;
  signal fifo_fc_all_trans_done_p           : std_logic;
  --signal fifo_fc_all_trans_done_p_sync      : std_logic;
  signal fifo_fc_all_trans_done_l           : std_logic;
  signal fifo_fc_full                       : std_logic;
  signal fifo_fc_full_l                     : std_logic;

  -- External memory interface signals
  signal ext_dout                           : std_logic_vector(g_data_width-1 downto 0);
  signal ext_valid                          : std_logic;
  signal ext_sof                            : std_logic;
  signal ext_eof                            : std_logic;
  signal ext_addr                           : std_logic_vector(g_ddr_addr_width-1 downto 0);
  signal ext_dreq                           : std_logic;
  signal ext_stall                          : std_logic;

  -- DDR3 signals
  signal ddr3_wr_all_trans_done_p           : std_logic;
  signal ddr3_wr_all_trans_done_l           : std_logic;
  signal sim_in_rb                          : std_logic;
  signal ddr3_rb_lmt_rb_rst                 : std_logic;
  signal acq_ddr3_rst_n                 : std_logic;

  signal dbg_ddr_rb_data                    : std_logic_vector(g_data_width-1 downto 0);
  signal dbg_ddr_rb_addr                    : std_logic_vector(g_addr_width-1 downto 0);
  signal dbg_ddr_rb_valid                   : std_logic;

  signal ddr3_rb_all_trans_done_p           : std_logic;
  --signal ddr3_rb_all_trans_done_p_sync      : std_logic;
  --signal ddr3_rb_all_trans_done_l           : std_logic;

  signal ddr3_all_trans_done_l              : std_logic;
  signal ddr3_all_trans_done_p              : std_logic;
  signal ddr3_all_trans_done_p_fs           : std_logic;

  -- UI multiplexed signals
  signal ui_app_rb_addr                     : std_logic_vector(g_ddr_addr_width-1 downto 0);
  signal ui_app_rb_cmd                      : std_logic_vector(2 downto 0);
  signal ui_app_rb_en                       : std_logic;
  signal ui_app_rb_req                      : std_logic;
  signal ui_app_rb_gnt                      : std_logic;

  signal ui_app_wdf_addr                    : std_logic_vector(g_ddr_addr_width-1 downto 0);
  signal ui_app_wdf_cmd                     : std_logic_vector(2 downto 0);
  signal ui_app_wdf_en                      : std_logic;
  signal ui_app_wdf_req                     : std_logic;
  signal ui_app_wdf_gnt                     : std_logic;

  -- RAM address counter
  signal test_data_en                       : std_logic;
  signal trig_addr                          : std_logic_vector(31 downto 0);

  ------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------

  component acq_core_regs
  port (
    rst_n_i                                  : in     std_logic;
    clk_sys_i                                : in     std_logic;
    wb_adr_i                                 : in     std_logic_vector(3 downto 0);
    wb_dat_i                                 : in     std_logic_vector(31 downto 0);
    wb_dat_o                                 : out    std_logic_vector(31 downto 0);
    wb_cyc_i                                 : in     std_logic;
    wb_sel_i                                 : in     std_logic_vector(3 downto 0);
    wb_stb_i                                 : in     std_logic;
    wb_we_i                                  : in     std_logic;
    wb_ack_o                                 : out    std_logic;
    wb_stall_o                               : out    std_logic;
    fs_clk_i                                 : in     std_logic;
    --ext_clk_i                                : in     std_logic;
    regs_i                                   : in     t_acq_core_in_registers;
    regs_o                                   : out    t_acq_core_out_registers
  );
  end component;

begin

  -----------------------------
  -- Slave adapter for Wishbone Register Interface
  -----------------------------
  cmp_slave_adapter : wb_slave_adapter
  generic map (
    g_master_use_struct                     => true,
    g_master_mode                           => PIPELINED,
    g_master_granularity                    => WORD,
    g_slave_use_struct                      => false,
    g_slave_mode                            => g_interface_mode,
    g_slave_granularity                     => g_address_granularity
  )
  port map (
    clk_sys_i                               => sys_clk_i,
    rst_n_i                                 => sys_rst_n_i,
    master_i                                => wb_slv_adp_in,
    master_o                                => wb_slv_adp_out,
    sl_adr_i                                => resized_addr,
    sl_dat_i                                => wb_dat_i,
    sl_sel_i                                => wb_sel_i,
    sl_cyc_i                                => wb_cyc_i,
    sl_stb_i                                => wb_stb_i,
    sl_we_i                                 => wb_we_i,
    sl_dat_o                                => wb_dat_o,
    sl_ack_o                                => wb_ack_o,
    sl_rty_o                                => wb_rty_o,
    sl_err_o                                => wb_err_o,
    sl_int_o                                => open,
    sl_stall_o                              => wb_stall_o
  );

  resized_addr(c_periph_addr_size-1 downto 0)
                                            <= wb_adr_i(c_periph_addr_size-1 downto 0);
  resized_addr(c_wishbone_address_width-1 downto c_periph_addr_size)
                                            <= (others => '0');

  -----------------------------
  -- BPM Acq Register Wishbone Interface. Word addressed!
  -----------------------------
  --BPM Acq register interface, word addressed
  cmp_acq_core_regs : acq_core_regs
  port map(
    rst_n_i                                 => sys_rst_n_i,
    clk_sys_i                               => sys_clk_i,
    wb_adr_i                                => wb_slv_adp_out.adr(3 downto 0),
    wb_dat_i                                => wb_slv_adp_out.dat,
    wb_dat_o                                => wb_slv_adp_in.dat,
    wb_cyc_i                                => wb_slv_adp_out.cyc,
    wb_sel_i                                => wb_slv_adp_out.sel,
    wb_stb_i                                => wb_slv_adp_out.stb,
    wb_we_i                                 => wb_slv_adp_out.we,
    wb_ack_o                                => wb_slv_adp_in.ack,
    wb_stall_o                              => wb_slv_adp_in.stall,
    fs_clk_i                                => fs_clk_i,
    --ext_clk_i                               => ext_clk_i,
    regs_i                                  => regs_in,
    regs_o                                  => regs_out
  );

  -- Unused wishbone signals
  wb_slv_adp_in.int                         <= '0';
  wb_slv_adp_in.err                         <= '0';
  wb_slv_adp_in.rty                         <= '0';

  -- Input register assignments
  --regs_in.sta_fsm_i                         <= acq_fsm_state;
  --regs_in.sta_reserved_i                    <= (others => '0');
  --regs_in.trig_pos_i                        <= (others => '0');
  --regs_in.samples_cnt_i                     <= std_logic_vector(samples_cnt);

  pre_trig_samples_c                        <= unsigned(regs_out.pre_samples_o);
  post_trig_samples_c                       <= unsigned(regs_out.post_samples_o);
  shots_nb_c                                <= unsigned(regs_out.shots_nb_o);

  --acq_ddr3_start_addr                       <= (others => '0');
  -- Synchronous to ext_clk_i
  acq_ddr3_start_addr_full                  <= regs_out.ddr3_start_addr_o;

  -- Truncate address to the actually width of external memory
  -- Synchronous to ext_clk_i
  --acq_ddr3_start_addr                       <= acq_ddr3_start_addr_full(acq_ddr3_start_addr'left downto c_ddr_align_shift);
  acq_ddr3_start_addr                       <= acq_ddr3_start_addr_full(acq_ddr3_start_addr'left downto 0);

  --acq_start                                 <= '1' when regs_out.ctl_fsm_cmd_wr_o = '1' and
  --                                             regs_out.ctl_fsm_cmd_o = "01" else '0';
  --acq_stop                                  <= '1' when regs_out.ctl_fsm_cmd_wr_o = '1' and
  --                                             regs_out.ctl_fsm_cmd_o = "10" else '0';
  acq_start                                 <= regs_out.ctl_fsm_start_acq_o; -- 1 fs_clk cycle pulse
  acq_stop                                  <= regs_out.ctl_fsm_stop_acq_o; -- 1 fs_clk cycle pulse
  acq_now                                   <= regs_out.ctl_fsm_acq_now_o;

  regs_in.sta_fsm_state_i                   <= acq_fsm_state;
  regs_in.sta_fsm_acq_done_i                <= acq_end;
  regs_in.sta_reserved1_i                   <= (others => '0');
  regs_in.sta_fc_trans_done_i               <= fifo_fc_all_trans_done_l;
  regs_in.sta_fc_full_i                     <= fifo_fc_full_l;
  regs_in.sta_reserved2_i                   <= (others => '0');
  regs_in.sta_ddr3_trans_done_i             <= ddr3_all_trans_done_l;
  --regs_in.sta_ddr3_rb_trans_done_i          <= ddr3_all_trans_done_l;
  regs_in.sta_reserved3_i                   <= (others => '0');
  regs_in.trig_pos_i                        <= (others => '0');
  regs_in.samples_cnt_i                     <= std_logic_vector(samples_cnt);

  cmp_acq_fsm : acq_fsm
  --generic map
  --(
  --)
  port map
  (
    fs_clk_i                                  => fs_clk_i,
    fs_ce_i                                   => fs_ce_i,
    fs_rst_n_i                                => fs_rst_n_i,

    -----------------------------
    -- FSM Commands (Inputs)
    -----------------------------
    acq_start_i                               => acq_start,
    acq_now_i                                 => acq_now,
    acq_stop_i                                => acq_stop,
    acq_trig_i                                => '0',
    acq_dvalid_i                              => dvalid_i,

    -----------------------------
    -- FSM Number of Samples
    -----------------------------
    pre_trig_samples_i                        => pre_trig_samples_c,
    post_trig_samples_i                       => post_trig_samples_c,
    shots_nb_i                                => shots_nb_c,
    samples_cnt_o                             => samples_cnt,

    -----------------------------
    -- FSM Monitoring
    -----------------------------
    --acq_end_p_o                               : out std_logic;
    acq_end_o                                 => acq_end,
    acq_single_shot_o                         => acq_single_shot,
    acq_in_pre_trig_o                         => acq_in_pre_trig,
    acq_in_wait_trig_o                        => acq_in_wait_trig,
    acq_in_post_trig_o                        => acq_in_post_trig,
    acq_pre_trig_done_o                       => acq_pre_trig_done,
    acq_wait_trig_skip_done_o                 => acq_wait_trig_skip_done,
    acq_post_trig_done_o                      => acq_post_trig_done,
    acq_fsm_state_o                           => acq_fsm_state,

    -----------------------------
    -- FSM Outputs
    -----------------------------
    shots_decr_o                              => shots_decr,
    acq_trig_o                                => acq_trig,
    multishot_buffer_sel_o                    => multishot_buffer_sel,
    samples_wr_en_o                           => samples_wr_en
  );

  ------------------------------------------------------------------------------
  -- Dual DPRAM buffers for multi-shots acquisition
  -----------------------------------------------------------------------------
  cmp_acq_multishot_dpram : acq_multishot_dpram
  generic map
  (
    g_data_width                            => g_data_width,
    g_multishot_ram_size                    => g_multishot_ram_size
  )
  port map
  (
    fs_clk_i                                => fs_clk_i,
    fs_ce_i                                 => fs_ce_i,
    fs_rst_n_i                              => fs_rst_n_i,

    data_i                                  => data_i,
    dvalid_i                                => dvalid_i,
    wr_en_i                                 => samples_wr_en,
    addr_rst_i                              => shots_decr,

    buffer_sel_i                            => multishot_buffer_sel,
    acq_trig_i                              => acq_trig,

    pre_trig_samples_i                      => pre_trig_samples_c,
    post_trig_samples_i                     => post_trig_samples_c,

    acq_pre_trig_done_i                     => acq_pre_trig_done,
    acq_wait_trig_skip_done_i               => acq_wait_trig_skip_done,
    acq_post_trig_done_i                    => acq_post_trig_done,

    dpram_dout_o                            => dpram_dout,
    dpram_valid_o                           => dpram_valid
  );

  dpram_dout_o                              <=  dpram_dout;
  dpram_valid_o                             <=  dpram_valid;

  ------------------------------------------------------------------------------
  -- Flow control FIFO for data to DDR
  ------------------------------------------------------------------------------

  cmp_acq_fc_fifo : acq_fc_fifo
  generic map (
    g_data_width                            => g_data_width,
    g_fifo_size                             => g_fifo_fc_size,
    g_addr_width                            => g_addr_width
  )
  port map
  (
    fs_clk_i                                => fs_clk_i,
    fs_ce_i                                 => fs_ce_i,
    fs_rst_n_i                              => fs_rst_n_i,

    -- DDR3 external clock
    ext_clk_i                               => ext_clk_i,
    ext_rst_n_i                             => ext_rst_n_i,

    dpram_data_i                            => dpram_dout,
    dpram_dvalid_i                          => dpram_valid,

    pt_data_i                               => data_i,
    pt_dvalid_i                             => dvalid_i,
    pt_wr_en_i                              => samples_wr_en,

    -- Request transaction reset as soon as possible (when all outstanding
    -- transactions have been commited)
    req_rst_trans_i                         => fifo_fc_req_rst_trans, -- FIXME: Could this be acq_start = '1'???
    -- Select between multi-buffer mode and pass-through mode (data directly
    -- through external module interface)
    passthrough_en_i                        => acq_single_shot,
    -- Which buffer (0 or 1) to store data in. Valid only when passthrough_en_i = '0'
    buffer_sel_i                            => multishot_buffer_sel,

    -- Size of the transaction in g_size bytes
    lmt_pkt_size_i                          => lmt_acq_pkt_size,
    -- Number of shots in this acquisition
    lmt_shots_nb_i                          => lmt_shots_nb,
    --lmt_valid_i                             => lmt_valid,
    lmt_valid_i                             => acq_start_sync_ext,

    fifo_fc_all_trans_done_p_o              => fifo_fc_all_trans_done_p,
    -- Asserted when the Acquisition FIFO is full. Data is lost when this signal is
    -- set and valid data keeps coming
    fifo_fc_full_o                          => fifo_fc_full,

    fifo_fc_dout_o                          => ext_dout,
    fifo_fc_valid_o                         => ext_valid,
    fifo_fc_addr_o                          => ext_addr,
    fifo_fc_sof_o                           => ext_sof,
    fifo_fc_eof_o                           => ext_eof,
    fifo_fc_dreq_i                          => ext_dreq,
    fifo_fc_stall_i                         => ext_stall
  );

  -- Wait for all packtes of the last transaction to be comitted. Convert from
  -- pulse to level signal
  p_fifo_fc_all_trans : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        fifo_fc_all_trans_done_l <= '0';
      else
        if fifo_fc_all_trans_done_p = '1' then
          fifo_fc_all_trans_done_l <= '1';
        elsif acq_start = '1'then
          fifo_fc_all_trans_done_l <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Warn user that data might have been lost because the FIFO became full!
  p_fifo_fc_full : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        fifo_fc_full_l <= '0';
      else
        if fifo_fc_full = '1' then
          fifo_fc_full_l <= '1';
        elsif acq_start = '1'then
          fifo_fc_full_l <= '0';
        end if;
      end if;
    end if;
  end process;

  -- When FSM in IDLE, request reset
  fifo_fc_req_rst_trans <= '1' when acq_fsm_state = "001" else '0';

  p_total_acq_sample : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        lmt_acq_pkt_size <= to_unsigned(0, lmt_acq_pkt_size'length);
        lmt_shots_nb <= to_unsigned(0, lmt_shots_nb'length);
        --lmt_valid <= '0';
      else
        if acq_start = '1' then
          -- Be pessimist about overflow. Pick only the LSB of trig samples
          lmt_acq_pkt_size <= unsigned('0' & pre_trig_samples_c(c_acq_samples_size-2 downto 0)) +
                              unsigned('0' & post_trig_samples_c(c_acq_samples_size-2 downto 0));
          lmt_shots_nb <= shots_nb_c;
          --lmt_valid <= '1';
        --elsif ddr3_all_trans_done_p = '1' then -- last *_done type of signal in the pipeline
          --lmt_valid <= '0';
        end if;
      end if;
    end if;
  end process;

  lmt_valid <= acq_start;

  ext_dout_o                                <= ext_dout;
  ext_valid_o                               <= ext_valid;
  ext_addr_o                                <= ext_addr;
  ext_sof_o                                 <= ext_sof;
  ext_eof_o                                 <= ext_eof;
  ext_dreq_o                                <= ext_dreq;   -- for debugging purposes
  ext_stall_o                               <= ext_stall;  -- for debugging purposes

  ------------------------------------------------------------------------------
  -- DDR3 Interface
  ------------------------------------------------------------------------------

  cmp_acq_ddr3_iface : acq_ddr3_iface
  generic map
  (
    g_data_width                              => g_data_width,
    g_addr_width                              => g_addr_width,
    -- Do not modify these! As they are dependent of the memory controller generated!
    g_ddr_payload_width                       => g_ddr_payload_width,
    g_ddr_addr_width                          => g_ddr_addr_width
  )
  port map
  (
    -- DDR3 external clock
    ext_clk_i                                 => ext_clk_i,
    ext_rst_n_i                               => ext_rst_n_i,

    -- Flow protocol to interface with external SDRAM. Evaluate the use of
    -- Wishbone Streaming protocol.
    fifo_fc_din_i                             => ext_dout,
    fifo_fc_valid_i                           => ext_valid,
    fifo_fc_addr_i                            => ext_addr,
    fifo_fc_sof_i                             => ext_sof,
    fifo_fc_eof_i                             => ext_eof,
    fifo_fc_dreq_o                            => ext_dreq,
    fifo_fc_stall_o                           => ext_stall,

    wr_start_i                                => acq_start_sync_ext,
    -- "acq_ddr3_start_addr" is synced with sys_clk, but we only read it after
    -- acq_start_sync_ext is set, which is sync to ext_clk. So, that does not
    -- impose any metastability problem in this module
    wr_init_addr_i                            => acq_ddr3_start_addr,
    --start_wr_i                                => acq_start_sync_ext,
    --start_addr_i                              => acq_ddr3_start_addr,

    lmt_all_trans_done_p_o                    => ddr3_wr_all_trans_done_p,
    --lmt_rst_i                                 => acq_start_sync_ext,
    lmt_rst_i                                 => '0', --remove this signal

    -- Size of the transaction in g_fifo_size bytes
    lmt_pkt_size_i                            => lmt_acq_pkt_size,
    -- Number of shots in this acquisition
    lmt_shots_nb_i                            => lmt_shots_nb,
    -- Acquisition limits valid signal. Qualifies lmt_fifo_pkt_size_i and lmt_shots_nb_i
    --lmt_valid_i                               => lmt_valid,
    lmt_valid_i                               => acq_start_sync_ext,

    -- Xilinx DDR3 UI Interface
    ui_app_addr_o                             => ui_app_wdf_addr,   --: out std_logic_vector(g_ddr_addr_width-1 downto 0);
    ui_app_cmd_o                              => ui_app_wdf_cmd,    --: out std_logic_vector(2 downto 0);
    ui_app_en_o                               => ui_app_wdf_en,     --: out std_logic;
    ui_app_rdy_i                              => ui_app_rdy_i,      --: in std_logic;

    ui_app_wdf_data_o                         => ui_app_wdf_data_o, --: out std_logic_vector(g_ddr_payload_width-1 downto 0);
    ui_app_wdf_end_o                          => ui_app_wdf_end_o,  --: out std_logic;
    ui_app_wdf_mask_o                         => ui_app_wdf_mask_o, --: out std_logic_vector(g_ddr_payload_width/8-1 downto 0);
    ui_app_wdf_wren_o                         => ui_app_wdf_wren_o, --: out std_logic;
    ui_app_wdf_rdy_i                          => ui_app_wdf_rdy_i,  --: in std_logic

    ui_app_rd_data_i                          => ui_app_rd_data_i,
    ui_app_rd_data_end_i                      => ui_app_rd_data_end_i,
    ui_app_rd_data_valid_i                    => ui_app_rd_data_valid_i,

    ui_app_req_o                              => ui_app_wdf_req,
    ui_app_gnt_i                              => ui_app_wdf_gnt
  );

  cmp_sync_req_rst : gc_sync_ffs
    port map(
      clk_i                                   => ext_clk_i,
      rst_n_i                                 => ext_rst_n_i,
      data_i                                  => acq_start,
      synced_o                                => acq_start_sync_ext,
      npulse_o                                => open,
      ppulse_o                                => open
    );

  -- Only for simulation!
  gen_ddr3_readback : if (g_sim_readback) generate

    -- Convert from pulse to level signal
    p_ddr3_wr_all_trans_done : process (ext_clk_i)
    begin
      if rising_edge(ext_clk_i) then
        if ext_rst_n_i = '0' then
          ddr3_wr_all_trans_done_l <= '0';
        else
          if ddr3_wr_all_trans_done_p = '1' then
            ddr3_wr_all_trans_done_l <= '1';
          elsif acq_start_sync_ext = '1'then
            ddr3_wr_all_trans_done_l <= '0';
          end if;
        end if;
      end if;
    end process;

    sim_in_rb <= ddr3_wr_all_trans_done_l;
    ddr3_rb_lmt_rb_rst <= not ddr3_wr_all_trans_done_l;

    cmp_acq_ddr3_read : acq_ddr3_read
    generic map
    (
      g_data_width                          => g_data_width,
      g_addr_width                          => g_addr_width,
      -- Do not modify these! As they are dependent of the memory controller generated!
      g_ddr_payload_width                   => g_ddr_payload_width,
      g_ddr_addr_width                      => g_ddr_addr_width
    )
    port map
    (
      -- DDR3 external clock
      ext_clk_i                             => ext_clk_i,
      ext_rst_n_i                           => ext_rst_n_i,

      -- Flow protocol to interface with external SDRAM. Evaluate the use of
      -- Wishbone Streaming protocol.
      fifo_fc_din_o                         => dbg_ddr_rb_data,
      fifo_fc_valid_o                       => dbg_ddr_rb_valid,
      fifo_fc_addr_o                        => dbg_ddr_rb_addr,
      fifo_fc_sof_o                         => open,
      fifo_fc_eof_o                         => open,
      fifo_fc_dreq_i                        => '0',
      fifo_fc_stall_i                       => '0',

      rb_start_i                            => ddr3_wr_all_trans_done_p,
      -- "acq_ddr3_start_addr" is synced with sys_clk, but we only read it after
      -- ddr3_wr_all_trans_done_p is set, which is sync to ext_clk. So, that does not
      -- impose any metastability problem in this module
      rb_init_addr_i                        => acq_ddr3_start_addr,

      lmt_all_trans_done_p_o                => ddr3_rb_all_trans_done_p,
      lmt_rst_i                             => '0', -- remove this signal!

      -- Size of the transaction in g_fifo_size bytes
      lmt_pkt_size_i                        => lmt_acq_pkt_size, --Should be lmt_acq_pkt_size/4 !!!
      -- Number of shots in this acquisition
      lmt_shots_nb_i                        => lmt_shots_nb,
      -- Acquisition limits valid signal. Qualifies lmt_fifo_pkt_size_i and lmt_shots_nb_i
      --lmt_valid_i                           => lmt_valid,
      lmt_valid_i                           => acq_start_sync_ext,

      -- Xilinx DDR3 UI Interface
      ui_app_addr_o                         => ui_app_rb_addr,
      ui_app_cmd_o                          => ui_app_rb_cmd,
      ui_app_en_o                           => ui_app_rb_en,
      ui_app_rdy_i                          => ui_app_rdy_i,

      ui_app_rd_data_i                      => ui_app_rd_data_i,
      ui_app_rd_data_end_i                  => ui_app_rd_data_end_i,
      ui_app_rd_data_valid_i                => ui_app_rd_data_valid_i,

      ui_app_req_o                          => ui_app_rb_req,
      ui_app_gnt_i                          => ui_app_rb_gnt
    );

    acq_ddr3_rst_n                      <= ext_rst_n_i and ddr3_wr_all_trans_done_l;
    ddr3_all_trans_done_p                   <= ddr3_rb_all_trans_done_p;

    dbg_ddr_rb_data_o                       <= dbg_ddr_rb_data;
    dbg_ddr_rb_valid_o                      <= dbg_ddr_rb_valid;
    dbg_ddr_rb_addr_o                       <= dbg_ddr_rb_addr;

    -- Sync
    --cmp_sync_req_rst : gc_sync_ffs
    --port map(
    --  clk_i                                 => ext_clk_i,
    --  rst_n_i                               => ext_rst_n_i,
    --  data_i                                => fifo_fc_all_trans_done_p,
    --  synced_o                              => fifo_fc_all_trans_done_p_sync,
    --  npulse_o                              => open,
    --  ppulse_o                              => open
    --);

    -- Multiplex between write to DDR3 and readback from DDR3 (simulation only!)
    ui_app_addr_o <= ui_app_wdf_addr when sim_in_rb = '0' else ui_app_rb_addr;
    ui_app_cmd_o <= ui_app_wdf_cmd when sim_in_rb = '0' else ui_app_rb_cmd;
    ui_app_en_o <= ui_app_wdf_en when sim_in_rb = '0' else ui_app_rb_en;

    ui_app_req_o <= ui_app_wdf_req when sim_in_rb = '0' else ui_app_rb_req;

    ui_app_wdf_gnt <= ui_app_gnt_i when sim_in_rb = '0' else '0';
    ui_app_rb_gnt <= ui_app_gnt_i when sim_in_rb = '1' else '0';

  end generate;

  gen_ddr3_non_readback : if (not g_sim_readback) generate
    ddr3_all_trans_done_p <= ddr3_wr_all_trans_done_p;

    ui_app_addr_o <= ui_app_wdf_addr;
    ui_app_cmd_o <= ui_app_wdf_cmd;
    ui_app_en_o <= ui_app_wdf_en;

    ui_app_req_o <= ui_app_wdf_req;
    ui_app_wdf_gnt <= ui_app_gnt_i;
  end generate;

  -- Generate level signal to indicate DDR3 tranfer is complete
  cmp_gc_pulse_synchronizer : gc_pulse_synchronizer
  port map (
    clk_in_i                              => ext_clk_i,
    clk_out_i                             => fs_clk_i,
    rst_n_i                               => ext_rst_n_i,
    d_ready_o                             => open,
    d_p_i                                 => ddr3_all_trans_done_p, -- pulse input
    q_p_o                                 => ddr3_all_trans_done_p_fs -- pulse output
  );

  -- Convert from pulse to level signal
  p_ddr3_all_trans_done_l : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        ddr3_all_trans_done_l <= '0';
      else
        if ddr3_all_trans_done_p_fs = '1' then
          ddr3_all_trans_done_l <= '1';
        elsif acq_start = '1'then -- sync with fs_clk
          ddr3_all_trans_done_l <= '0';
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Store trigger DDR address
  ------------------------------------------------------------------------------
  --p_trig_addr : process (ext_clk_i)
  --begin
  --  if rising_edge(ext_clk_i) then
  --    if ext_rst_n_i = '0' then
  --      trig_addr <= (others => '0');
  --    else
  --      if acq_trig = '1' and ext_valid = '1' then
  --        trig_addr <= std_logic_vector(ext_addr);
  --      end if;
  --    end if;
  --  end if;
  --end process;

end rtl;