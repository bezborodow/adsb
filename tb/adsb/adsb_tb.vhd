library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;

entity adsb_tb is
--  port ( );
    generic (runner_cfg : string);
end adsb_tb;

architecture test of adsb_tb is
    signal input_i : signed(11 downto 0) := (others => '0');
    signal input_q : signed(11 downto 0) := (others => '0');

    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

    signal adsb_vld: std_logic := '0';
    signal adsb_rdy: std_logic := '0';
    signal adsb_data: std_logic_vector(111 downto 0) := (others =>'0');
    signal adsb_w56: std_logic := '0';

begin
    clk <= not clk after clk_period / 2;

    uut: entity work.adsb port map (
        clk => clk,
        i_i => input_i,
        q_i => input_q,
        vld_o => adsb_vld,
        rdy_i => adsb_rdy,
        data_o => adsb_data,
        w56_o => adsb_w56
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

        assert adsb_vld = '1' report "Not ready. Should be ready.";
        adsb_rdy <= '1';
        wait for clk_period;

        assert adsb_vld = '1';
        adsb_rdy <= '0';
        wait for clk_period;

        assert adsb_vld = '0';
        wait for clk_period * 20;

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;
end test;
