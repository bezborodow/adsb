----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.04.2025 04:11:22
-- Design Name: 
-- Module Name: schmitt_iq_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;


entity schmitt_iq_tb is
--  Port ( );
end schmitt_iq_tb;

architecture test of schmitt_iq_tb is
    component schmitt_trigger is
        Port (
            input_i : in std_logic_vector(11 downto 0);
            input_q : in std_logic_vector(11 downto 0);
            output : out std_logic;
            clk : in std_logic
       );
    end component;
    
    signal input_i : std_logic_vector (11 downto 0) := (others => '0');
    signal input_q : std_logic_vector (11 downto 0) := (others => '0');
    signal output : std_logic := '0';

    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.
    
begin
    clk <= not clk after clk_period / 2;
    
    uut: schmitt_trigger port map (
        input_i => input_i,
        input_q => input_q,
        output => output,
        clk => clk
    );
    
    stimulus : process
        file iq_file : text open read_mode is "C:/VivadoProjects/schmitt_trigger/schmitt_trigger.srcs/sim_1/new/iq_data.txt";
        variable line_buf : line;
        variable line_i, line_q : integer;
    begin
        while not endfile(iq_file) loop
          readline(iq_file, line_buf);
          read(line_buf, line_i);
          read(line_buf, line_q);
          
          input_i <= std_logic_vector(to_signed(line_i, 12));
          input_q <= std_logic_vector(to_signed(line_q, 12));
          
          wait for clk_period;
        end loop;
        
        wait;
    end process;

end test;
