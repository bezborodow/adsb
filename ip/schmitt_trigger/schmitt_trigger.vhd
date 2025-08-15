----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.04.2025 01:49:26
-- Design Name: 
-- Module Name: schmitt_trigger - Behavioral
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
use ieee.numeric_std.all;

entity schmitt_trigger is
    port (
        magnitude_sq : in unsigned(24 downto 0);
        high_threshold : in unsigned(24 downto 0) := (others => '0');
        low_threshold : in unsigned(24 downto 0) := (others => '0');
        output : out std_logic;
        ce : in std_logic := '0'; -- Clock enable.
        clk : in std_logic
    );
end schmitt_trigger;

architecture Behavioral of schmitt_trigger is
begin
    trigger_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce then
                if (magnitude_sq > high_threshold) then
                    output <= '1';
                elsif (magnitude_sq < low_threshold) then
                    output <= '0';
                end if;
            else
                output <= '0';
            end if;
        end if;
    end process trigger_process;
end Behavioral;

