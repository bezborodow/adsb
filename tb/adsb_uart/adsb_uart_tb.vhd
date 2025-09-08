library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;

entity adsb_uart_tb is
--  port ( );
    generic (runner_cfg : string);
end adsb_uart_tb;

architecture test of adsb_uart_tb is
    signal input_i : signed(11 downto 0) := (others => '0');
    signal input_q : signed(11 downto 0) := (others => '0');

    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

    signal adsb_uart_tx: std_logic := '0';

begin
    clk <= not clk after clk_period / 2;

    uut : entity work.adsb_uart
        generic map (
            RX_IQ_WIDTH => 12,
            IQ_WIDTH => 12,
            SAMPLES_PER_SYMBOL => 10,
            PREAMBLE_BUFFER_LENGTH => 160,
            PREAMBLE_POSITION1 => 20,
            PREAMBLE_POSITION2 => 70,
            PREAMBLE_POSITION3 => 90,
            ACCUMULATION_LENGTH => 1024,
            UART_CLK_DIV => 174
        )
        port map (
            clk => clk,
            d_vld_i => '1',
            i_i => input_i,
            q_i => input_q,
            uart_tx_o => adsb_uart_tx
        );

    main : process
        file iq_file : text open read_mode is "tb/schmitt_trigger/iq_data.txt";
        variable line_buf : line;
        variable line_i, line_q : integer;
    begin
        test_runner_setup(runner, runner_cfg);
        report "Hello world!";
        while not endfile(iq_file) loop
            readline(iq_file, line_buf);
            read(line_buf, line_i);
            read(line_buf, line_q);

            input_i <= to_signed(line_i, 12);
            input_q <= to_signed(line_q, 12);

            wait for clk_period;
        end loop;

        wait for clk_period * 10000;

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;
end test;
