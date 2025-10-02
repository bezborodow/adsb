library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;
use work.adsb_pkg.all;


entity freq_est_tb is
--  port ( );
    generic (runner_cfg : string);
end freq_est_tb;
architecture test of freq_est_tb is
    signal clk : std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

    signal start : std_logic := '0';
    signal stop : std_logic := '0';
    signal i : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal q : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal gate : std_logic := '0';
    signal vld : std_logic := '0';
    signal rdy : std_logic := '0';
    signal est_re : signed(31 downto 0) := (others => '0');
    signal est_im : signed(31 downto 0) := (others => '0');

begin
    clk <= not clk after clk_period / 2;

    uut : entity work.freq_est
        generic map (
            ACCUMULATION_LENGTH => 1024
        )
        port map (
            clk => clk,
            ce_i => '1',
            start_i => start,
            stop_i => stop,
            i_i => i,
            q_i => q,
            gate_i => gate,
            vld_o => vld,
            rdy_i => rdy,
            est_re_o => est_re,
            est_im_o => est_im
        );

    main : process
        file iq_file : text open read_mode is "tb/data/20e6/synth/iq_data.txt";
        variable line_buf : line;
        variable line_i, line_q : integer;
        variable input_i : signed(11 downto 0) := (others => '0');
        variable input_q : signed(11 downto 0) := (others => '0');
        variable magnitude_sq : unsigned(24 downto 0) := (others => '0');
        variable line_counter : integer := 0;
    begin
        test_runner_setup(runner, runner_cfg);
        while not endfile(iq_file) loop
            readline(iq_file, line_buf);
            read(line_buf, line_i);
            read(line_buf, line_q);

            input_i := to_signed(line_i, 12);
            input_q := to_signed(line_q, 12);
            magnitude_sq := to_unsigned(to_integer(input_i) * to_integer(input_i) + to_integer(input_q) * to_integer(input_q), magnitude_sq'length);
            gate <= '1' when magnitude_sq > 50000 else '0';
            i <= input_i;
            q <= input_q;

            if line_counter = 0 then
                start <= '1';
            else
                start <= '0';
            end if;

            line_counter := line_counter + 1;

            wait for clk_period;
        end loop;

        stop <= '1';
        wait for clk_period;
        stop <= '0';
        wait for clk_period;

        assert vld = '1';
        rdy <= '1';
        wait for clk_period;

        rdy <= '0';
        wait for clk_period;

        assert vld = '0';
        wait for clk_period * 20;

        assert vld = '0';

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;
end test;
