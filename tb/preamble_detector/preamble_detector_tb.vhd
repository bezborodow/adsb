library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;

entity preamble_detector_tb is
--  port ( );
    generic (runner_cfg : string);
end preamble_detector_tb;

architecture test of preamble_detector_tb is
    signal i_i : signed(11 downto 0) := (others => '0');
    signal q_i : signed(11 downto 0) := (others => '0');
    signal detect : std_logic := '0';

    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

begin
    clk <= not clk after clk_period / 2;
    
    uut: entity work.preamble_detector port map (
        clk => clk,
        ce_i => '1',
        i_i => i_i,
        q_i => q_i,
        detect_o => detect
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
          
          i_i <= to_signed(line_i, 12);
          q_i <= to_signed(line_q, 12);
          
          wait for clk_period;
        end loop;
        
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;
end test;
