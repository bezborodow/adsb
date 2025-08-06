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
    component preamble_detector is
        port (
            input_i : in signed(11 downto 0);
            input_q : in signed(11 downto 0);
            detect : out std_logic;
            clk : in std_logic
       );
    end component;
    
    signal input_i : signed(11 downto 0) := (others => '0');
    signal input_q : signed(11 downto 0) := (others => '0');
    signal detect : std_logic := '0';

    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.
    
begin
    clk <= not clk after clk_period / 2;
    
    uut: preamble_detector port map (
        input_i => input_i,
        input_q => input_q,
        detect => detect,
        clk => clk
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
        
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;
end test;
