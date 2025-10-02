library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.adsb_pkg.all;

entity adsb_uart_tb is
end adsb_uart_tb;

architecture test of adsb_uart_tb is
    signal input_i : signed(ADC_RX_IQ_WIDTH-1 downto 0) := (others => '0');
    signal input_q : signed(ADC_RX_IQ_WIDTH-1 downto 0) := (others => '0');

    signal clk: std_logic := '1';
    constant clk_period : time := 16.276 ns; -- 61.44 MHz sample rate.

    signal adsb_uart_tx: std_logic := '0';

begin
    clk <= not clk after clk_period / 2;

    uut : entity work.adsb_uart
        port map (
            clk => clk,
            d_vld_i => '1',
            i_i => input_i,
            q_i => input_q,
            uart_tx_o => adsb_uart_tx
        );

    main : process
        file iq_file : text open read_mode is "adsb_61_440_000_hertz.dat";
        variable line_buf : line;
        variable line_i, line_q : integer;
    begin
        while not endfile(iq_file) loop
            readline(iq_file, line_buf);
            read(line_buf, line_i);
            read(line_buf, line_q);

            input_i <= to_signed(line_i, ADC_RX_IQ_WIDTH);
            input_q <= to_signed(line_q, ADC_RX_IQ_WIDTH);

            wait for clk_period;
        end loop;
        wait;
    end process main;
end test;
