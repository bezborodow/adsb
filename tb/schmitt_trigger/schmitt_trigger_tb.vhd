library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.adsb_pkg.all;
library vunit_lib;
context vunit_lib.vunit_context;


entity schmitt_trigger_tb is
--  port ( );
    generic (runner_cfg : string);
end schmitt_trigger_tb;

architecture test of schmitt_trigger_tb is
    signal magnitude_sq : unsigned(24 downto 0) := (others => '0');
    signal output : std_logic := '0';

    signal i_i                   : iq_t := (others => '0');
    signal q_i                   : iq_t := (others => '0');
    signal mag_sq_i              : mag_sq_t := (others => '0');
    signal detect_i              : std_logic := '0';

    signal i_o                   : iq_t;
    signal q_o                   : iq_t;
    signal detect_o              : std_logic := '0';

    signal clk : std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

begin
    clk <= not clk after clk_period / 2;

    uut : entity work.schmitt_trigger port map (
        i_i => i_i,
        q_i => q_i,
        mag_sq_i => magnitude_sq,
        detect_i => detect_i,
        high_threshold_i => to_unsigned(500000, 25),
        low_threshold_i => to_unsigned(50000, 25),

        schmitt_o => output,
        detect_o => detect_o,
        i_o => i_o,
        q_o => q_o,
        ce_i => '1',
        clk => clk
    );

    main : process
        file iq_file : text open read_mode is "tb/data/20e6/synth/iq_data.txt";
        variable line_buf : line;
        variable line_i, line_q : integer;
        variable input_i : signed(11 downto 0) := (others => '0');
        variable input_q : signed(11 downto 0) := (others => '0');
    begin
        test_runner_setup(runner, runner_cfg);
        while not endfile(iq_file) loop
            readline(iq_file, line_buf);
            read(line_buf, line_i);
            read(line_buf, line_q);

            input_i := to_signed(line_i, 12);
            input_q := to_signed(line_q, 12);
            i_i <= input_i;
            q_i <= input_q;
            magnitude_sq <= to_unsigned(to_integer(input_i) * to_integer(input_i) + to_integer(input_q) * to_integer(input_q), magnitude_sq'length);

            -- TODO Implement test.
            wait for clk_period;
        end loop;

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;
end test;
