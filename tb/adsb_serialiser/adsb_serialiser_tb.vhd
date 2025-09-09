library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;

entity adsb_serialiser_tb is
--  port ( );
    generic (runner_cfg : string);
end adsb_serialiser_tb;

architecture test of adsb_serialiser_tb is
    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

    -- 56-bit ADS-B message (14 hex digits.)
    constant test_adsb_56 : std_logic_vector(55 downto 0) := x"AAA1B2C3D4E511";
    constant test_adsb_56_2 : std_logic_vector(55 downto 0) := x"DD90F280CB9A44";

    -- 112-bit ADS-B message (28 hex digits.)
    constant test_adsb_112 : std_logic_vector(111 downto 0) := x"AAA456789ABCDEF0123456789A11";
    constant test_adsb_112_2 : std_logic_vector(111 downto 0) := x"DD84E9F5654EC846A8E8F6DDDD44";

    -- 32-bit signed phasor integers.
    constant test_est_re : signed(31 downto 0) := x"BBB2AB22";
    constant test_est_im : signed(31 downto 0) := x"CC000033";
    constant test_est_re_2 : signed(31 downto 0) := x"EEB2AB55";
    constant test_est_im_2 : signed(31 downto 0) := x"FF000066";

    -- Master interface signals.
    signal srl_m_vld_i    : std_logic := '0';
    signal srl_m_rdy_o    : std_logic;
    signal srl_m_w56_i    : std_logic := '0';
    signal srl_m_data_i   : std_logic_vector(111 downto 0) := (others => '0');
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

    uut : entity work.adsb_serialiser
        port map (
            clk        => clk,
            m_vld_i    => srl_m_vld_i,
            m_rdy_o    => srl_m_rdy_o,
            m_w56_i    => srl_m_w56_i,
            m_data_i   => srl_m_data_i,
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

        if run("112bit") then
            assert srl_m_rdy_o = '1' report "Serialiser should be ready." severity failure;
            srl_m_est_re_i <= test_est_re;
            srl_m_est_im_i <= test_est_im;
            srl_m_data_i <= test_adsb_112;
            srl_m_vld_i <= '1';
            wait for clk_period;

            srl_m_vld_i <= '0';
            wait for clk_period;
            assert srl_m_rdy_o = '0' report "Serialiser should be busy." severity failure;
            wait for clk_period * 150;

            assert srl_m_rdy_o = '1' report "Serialiser should be ready." severity failure;
            srl_m_est_re_i <= test_est_re;
            srl_m_est_re_i <= test_est_re_2;
            srl_m_est_im_i <= test_est_im_2;
            srl_m_data_i <= test_adsb_112_2;
            srl_m_vld_i <= '1';
            wait for clk_period;

            srl_m_vld_i <= '0';
            wait for clk_period;
            assert srl_m_rdy_o = '0' report "Serialiser should be busy." severity failure;
            wait for clk_period * 150;
        end if;
        if run("56bit") then
            assert srl_m_rdy_o = '1' report "Serialiser should be ready." severity failure;
            srl_m_est_re_i <= test_est_re;
            srl_m_est_re_i <= test_est_re;
            srl_m_est_im_i <= test_est_im;
            srl_m_w56_i <= '1';
            srl_m_data_i <= x"00000000000000" & test_adsb_56;
            srl_m_vld_i <= '1';
            wait for clk_period;

            srl_m_vld_i <= '0';
            wait for clk_period;
            assert srl_m_rdy_o = '0' report "Serialiser should be busy." severity failure;
            wait for clk_period * 100;

            assert srl_m_rdy_o = '1' report "Serialiser should be ready." severity failure;
            srl_m_est_re_i <= test_est_re;
            srl_m_est_re_i <= test_est_re_2;
            srl_m_est_im_i <= test_est_im_2;
            srl_m_w56_i <= '1';
            srl_m_data_i <= x"00000000000000" & test_adsb_56_2;
            srl_m_vld_i <= '1';
            wait for clk_period;

            srl_m_vld_i <= '0';
            wait for clk_period;
            assert srl_m_rdy_o = '0' report "Serialiser should be busy." severity failure;
            wait for clk_period * 100;
        end if;

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;
end test;
