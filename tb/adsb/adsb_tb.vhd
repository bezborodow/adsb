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
    component adsb is
        port (
            i_i : in signed(11 downto 0);
            q_i : in signed(11 downto 0);
            clk : in std_logic
       );
    end component;
    
    signal input_i : signed(11 downto 0) := (others => '0');
    signal input_q : signed(11 downto 0) := (others => '0');

    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

begin
    clk <= not clk after clk_period / 2;

    uut: adsb port map (
        i_i => input_i,
        q_i => input_q,
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
