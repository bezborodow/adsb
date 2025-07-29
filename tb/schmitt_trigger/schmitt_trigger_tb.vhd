----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.04.2025 04:11:22
-- Design Name: 
-- Module Name: schmitt_trigger_tb - Behavioral
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


library ieee;
use ieee.std_logic_1164.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity schmitt_trigger_tb is
--  Port ( );
end schmitt_trigger_tb;

architecture test of schmitt_trigger_tb is
    component schmitt_trigger is
        Port ( input : in std_logic_vector(15 downto 0);
               output : out std_logic;
               clk : in std_logic
               );
    end component;
    
    signal input : std_logic_vector (15 downto 0) := (others => '0');
    signal output : std_logic := '0';
    
    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.
    
begin
    clk <= not clk after clk_period / 2;

    uut: schmitt_trigger port map (
        input => input,
        output => output,
        clk => clk
    );

    stimulus : process
    begin
        wait for 50 ns;
        input <= x"1000"; -- Below low threshold
        wait for 50 ns;
        input <= x"3000"; -- Above low, below high
        wait for 50 ns;
        input <= x"9000"; -- Near high threshold
        wait for 50 ns;
        input <= x"A100"; -- Above high threshold
        wait for 50 ns;
        input <= x"8000"; -- Falling back down
        wait for 50 ns;
        input <= x"1000"; -- Below low threshold
        wait for 50 ns;
        input <= x"2000"; -- On low threshold
        wait for 50 ns;
        input <= x"A000"; -- On high threshold
        wait for 50 ns;
        input <= x"FFFF"; -- Above high threshold
        wait for 500 ns;
        input <= x"9000";
        wait for 200 ns;
        input <= x"1000"; -- Below low threshold
        wait for 50 ns;
        input <= x"3000"; -- Above low, below high
        wait for 50 ns;
        input <= x"9000"; -- Near high threshold
        wait for 50 ns;
        input <= x"A100"; -- Above high threshold
        wait for 50 ns;
        input <= x"8000"; -- Falling back down
        wait for 50 ns;
        input <= x"1000"; -- Below low threshold
        wait for 50 ns;
        input <= x"2000"; -- On low threshold
        wait for 50 ns;
        input <= x"A000"; -- On high threshold
        wait for 50 ns;
        
        wait;
    end process;

end test;
