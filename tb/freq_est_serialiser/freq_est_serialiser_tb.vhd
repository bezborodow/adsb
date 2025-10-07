library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;

entity freq_est_serialiser_tb is
--  port ( );
    generic (runner_cfg : string);
end freq_est_serialiser_tb;

architecture test of freq_est_serialiser_tb is
    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

    -- 32-bit signed phasor integers.
    constant test_est_re : signed(31 downto 0) := x"BBB2AB22";
    constant test_est_im : signed(31 downto 0) := x"CC000033";
    constant test_est_re_2 : signed(31 downto 0) := x"EEB2AB55";
    constant test_est_im_2 : signed(31 downto 0) := x"FF000066";

    -- Master interface signals.
    signal srl_m_vld_i    : std_logic := '0';
    signal srl_m_rdy_o    : std_logic;
    signal srl_m_est_re_i : signed(31 downto 0) := (others => '0');
    signal srl_m_est_im_i : signed(31 downto 0) := (others => '0');

    -- Slave interface signals.
    signal srl_s_vld_o    : std_logic;
    signal srl_s_last_o   : std_logic;
    signal srl_s_rdy_i    : std_logic := '1';  -- Default ready.
    signal srl_s_data_o   : std_logic_vector(7 downto 0);
    signal srl_s_ascii_o  : std_logic;
    signal srl_s_eom_o    : std_logic;
begin
    clk <= not clk after clk_period / 2;

    uut : entity work.freq_est_serialiser
        port map (
            clk        => clk,
            ce_i       => '1',
            m_vld_i    => srl_m_vld_i,
            m_rdy_o    => srl_m_rdy_o,
            m_est_re_i => srl_m_est_re_i,
            m_est_im_i => srl_m_est_im_i,
            s_vld_o    => srl_s_vld_o,
            s_last_o   => srl_s_last_o,
            s_rdy_i    => srl_s_rdy_i,
            s_data_o   => srl_s_data_o,
            s_ascii_o  => srl_s_ascii_o,
            s_eom_o    => srl_s_eom_o
        );

    main : process
    begin
        test_runner_setup(runner, runner_cfg);

        wait for clk_period;

        assert srl_m_rdy_o = '1' report "Serialiser should be ready." severity failure;
        srl_m_est_re_i <= test_est_re;
        srl_m_est_im_i <= test_est_im;
        srl_m_vld_i <= '1';
        wait for clk_period;

        srl_m_vld_i <= '0';
        wait for clk_period;
        assert srl_m_rdy_o = '0' report "Serialiser should be busy." severity failure;
        wait for clk_period * 150;

        assert srl_m_rdy_o = '1' report "Serialiser should be ready." severity failure;
        srl_m_est_re_i <= test_est_re_2;
        srl_m_est_im_i <= test_est_im_2;
        srl_m_vld_i <= '1';
        wait for clk_period;

        srl_m_vld_i <= '0';
        wait for clk_period;
        assert srl_m_rdy_o = '0' report "Serialiser should be busy." severity failure;
        wait for clk_period * 150;

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;
end test;
