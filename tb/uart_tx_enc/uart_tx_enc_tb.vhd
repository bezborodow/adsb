library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.uart_pkg.all;
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

    signal end_of_test : boolean := false;

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

    stimulus_process : process
        constant MAX_CYCLES : natural := 1000;
        variable cycles_waited : natural := 0;
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
        wait for clk_period * 20;

        -- Send some numbers (converted to ASCII with newlines.)
        master_data <= x"AB";
        master_ascii <= '1';
        master_eom <= '0';
        master_vld <= '1';
        wait for clk_period;
        master_data <= x"CD";
        master_ascii <= '1';
        master_eom <= '0';
        master_vld <= '1';
        wait for clk_period;
        master_data <= x"EF";
        master_ascii <= '1';
        master_eom <= '1';
        master_vld <= '1';
        wait for clk_period;

        -- Wait for ready to be asserted.
        cycles_waited := 0;
        while master_rdy = '0' and cycles_waited < MAX_CYCLES loop
            wait until rising_edge(clk);
            cycles_waited := cycles_waited + 1;
        end loop;

        if master_rdy = '0' then
            report "Timeout waiting for ready signal." severity failure;
        end if;


        master_vld <= '0';
        
        -- End of test! Trigger checks!
        wait for clk_period * 30;
        end_of_test <= true;
        wait for clk_period;

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process stimulus_process;

    data_check_process : process(clk)
        variable done : boolean := false;
        variable counter : natural := 0;
        variable expected_data : uart_byte_array_t(0 to 11) := (
            0 => std_logic_vector(to_unsigned(character'pos('M'), 8)),
            1 => std_logic_vector(to_unsigned(character'pos('N'), 8)),
            2 => std_logic_vector(to_unsigned(character'pos('X'), 8)),
            3 => std_logic_vector(to_unsigned(character'pos('Y'), 8)),
            4 => std_logic_vector(to_unsigned(character'pos('Z'), 8)),
            5 => std_logic_vector(to_unsigned(character'pos('A'), 8)),
            6 => std_logic_vector(to_unsigned(character'pos('B'), 8)),
            7 => std_logic_vector(to_unsigned(character'pos('C'), 8)),
            8 => std_logic_vector(to_unsigned(character'pos('D'), 8)),
            9 => std_logic_vector(to_unsigned(character'pos('E'), 8)),
            10 => std_logic_vector(to_unsigned(character'pos('F'), 8)),
            11 => x"0A"
        );
    begin
        if rising_edge(clk) then
            if slave_vld = '1' and slave_rdy = '1' and not done then
                assert slave_data = expected_data(counter)
                report "Mismatch: expected=" & character'val(to_integer(unsigned(expected_data(counter)))) & " got=" & character'val(to_integer(unsigned(slave_data)))
                severity failure;

                counter := counter + 1;
                if counter = expected_data'length then
                    done := true;
                end if;
            end if;

            if end_of_test and not done then
                report "Did not receive all expected data." severity failure;
            end if;
        end if;
    end process data_check_process;
end test;
