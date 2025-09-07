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
    constant clk_period : time := 20 ns;

    signal master_vld : std_logic := '0';
    signal master_rdy : std_logic := '0';
    signal master_data : std_logic_vector(7 downto 0) := (others => '0');
    signal master_ascii : std_logic := '0';
    signal master_eom : std_logic := '0';

    signal slave_vld : std_logic := '0';
    signal slave_rdy : std_logic := '0';
    signal slave_data : std_logic_vector(7 downto 0) := (others => '0');

    procedure wait_for_clock_cycles(signal clock : std_logic; n : natural) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clock);
      end loop;
    end procedure;
begin
    clk <= not clk after clk_period / 2;

    uut : entity work.uart_tx_enc
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

        -- Idle.
        wait_for_clock_cycles(clk, 10);

        -- Put some data out on the line.
        assert master_rdy = '1' report "Master should be ready." severity failure;
        assert slave_vld = '0' report "No data should be valid for the slave yet." severity failure;
        assert slave_rdy = '0' report "Slave should be busy." severity failure;

        master_data <= x"4D";
        master_ascii <= '0';
        master_eom <= '0';
        master_vld <= '1';
        wait for clk_period;
        assert master_rdy = '1' report "Master should be ready." severity failure;
        master_vld <= '0';
        wait for clk_period * 3;

        -- Idle for a while with the slave being busy.
        wait for clk_period * 10;
        assert master_rdy = '1' report "Master should be ready." severity failure;

        -- Choke up the encoder and sender buffer.
        master_data <= x"4E";
        master_vld <= '1';
        wait until rising_edge(clk);

        master_vld <= '0';
        wait until rising_edge(clk);
        --assert master_rdy = '0' report "Master should not be ready." severity failure;

        -- Idle for a while longer with the slave still being busy.
        wait for clk_period * 10;

        -- Free up the slave to allow data to flow.
        slave_rdy <= '1';
        wait for clk_period;

        master_vld <= '0';
        wait for clk_period * 10;

        -- Send three characters consecutively (XYZ) without any back pressure
        -- from the slave.
        slave_rdy <= '1';
        master_vld <= '1';
        master_data <= x"58";
        master_ascii <= '0';
        wait for clk_period;
        master_data <= x"59";
        wait for clk_period;
        master_data <= x"5A";
        wait for clk_period;

        master_vld <= '0';
        wait for clk_period * 10;

        -- Send some numbers (converted to ASCII with newlines.)

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;
end test;
