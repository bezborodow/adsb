library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;
use work.adsb_pkg.all;

entity freq_est_uart_tb is
--  port ( );
    generic (runner_cfg : string);
end freq_est_uart_tb;

architecture test of freq_est_uart_tb is
    signal input_i : signed(ADC_RX_IQ_WIDTH-1 downto 0) := (others => '0');
    signal input_q : signed(ADC_RX_IQ_WIDTH-1 downto 0) := (others => '0');

    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

    signal freq_uart_tx: std_logic := '0';

begin
    clk <= not clk after clk_period / 2;

    uut : entity work.freq_est_uart
        generic map (
            ACCUMULATION_LENGTH    => 1024,
            UART_CLK_DIV           => 4 -- Don't choose a realistic baud rate, because the testbench will take forever.
        )
        port map (
            clk => clk,
            d_vld_i => '1',
            i_i => input_i,
            q_i => input_q,
            uart_tx_o => freq_uart_tx
        );

    main : process
        file iq_file : text open read_mode is "tb/data/20e6/synth/iq_data.txt";
        variable line_buf : line;
        variable line_i, line_q : integer;
    begin
        test_runner_setup(runner, runner_cfg);
        while not endfile(iq_file) loop
            readline(iq_file, line_buf);
            read(line_buf, line_i);
            read(line_buf, line_q);

            input_i <= to_signed(line_i, ADC_RX_IQ_WIDTH);
            input_q <= to_signed(line_q, ADC_RX_IQ_WIDTH);

            wait for clk_period;
        end loop;

        -- Close and reopen the file.
        file_close(iq_file);
        file_open(iq_file, "tb/data/20e6/synth/iq_data.txt", read_mode);

        -- Second pass to check that consecutive messages can be received.
        while not endfile(iq_file) loop
            readline(iq_file, line_buf);
            read(line_buf, line_i);
            read(line_buf, line_q);

            input_i <= to_signed(line_i, ADC_RX_IQ_WIDTH);
            input_q <= to_signed(line_q, ADC_RX_IQ_WIDTH);

            wait for clk_period;
        end loop;

        wait for clk_period * 10000;

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;
end test;
