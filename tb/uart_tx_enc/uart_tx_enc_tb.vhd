library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;


entity uart_tx_enc_tb is
--  port ( );
    generic (runner_cfg : string);
end uart_tx_enc_tb;

architecture test of uart_tx_enc_tb is
    signal clk : std_logic := '1';
    constant clk_period : time := 16 ns;

    constant ENC_DATA_WIDTH : integer := 8;

    signal master_vld : std_logic := '0';
    signal master_rdy : std_logic := '0';
    signal master_data : std_logic_vector(ENC_DATA_WIDTH-1 downto 0) := (others => '0');
    signal master_ascii : std_logic := '0';
    signal master_eom : std_logic := '0';

    signal slave_vld : std_logic := '0';
    signal slave_rdy : std_logic := '0';
    signal slave_data : std_logic_vector(ENC_DATA_WIDTH-1 downto 0) := (others => '0');

begin
    clk <= not clk after clk_period / 2;

    uut : entity work.uart_tx_enc
        generic map (
            DATA_WIDTH => ENC_DATA_WIDTH
        )
        port map (
            clk => clk,
            m_vld_i => master_vld,
            m_rdy_o => master_rdy,
            m_data_i => master_data,
            m_ascii_i => master_ascii,
            m_eom_i => master_eom,
            s_vld_o => slave_vld,
            s_rdy_i => slave_rdy,
            s_data_o => slave_data
        );

    main : process
    begin
        test_runner_setup(runner, runner_cfg);

        wait for clk_period;

        --assert master_rdy = '1' report "Master should be ready." severity failure;
        wait for clk_period;

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;
end test;
