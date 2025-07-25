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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity schmitt_trigger is
    Port (
        input_i : in std_logic_vector(11 downto 0);
        input_q : in std_logic_vector(11 downto 0);
        output : out std_logic;
        clk : in std_logic
    );
end schmitt_trigger;

architecture Behavioral of schmitt_trigger is
    constant high_threshold : unsigned(11 downto 0) := to_unsigned(500, 12);
    constant low_threshold : unsigned(11 downto 0) := to_unsigned(50, 12);
            
            
    signal magnitude_sq_debug : unsigned(23 downto 0);
begin
    trigger_process : process(clk)
        variable input_i_sq : signed(23 downto 0);
        variable input_q_sq : signed(23 downto 0);
        variable magnitude_sq : unsigned(23 downto 0);
        variable high_threshold_sq : unsigned(23 downto 0);
        variable low_threshold_sq : unsigned(23 downto 0);
    begin
        if (rising_edge(clk)) then
            input_i_sq := signed(input_i) * signed(input_i);
            input_q_sq := signed(input_q) * signed(input_q);
            magnitude_sq := unsigned(input_i_sq) + unsigned(input_q_sq);
            high_threshold_sq := high_threshold * high_threshold;
            low_threshold_sq := low_threshold * low_threshold;
            
            if (magnitude_sq > high_threshold_sq) then
                output <= '1';
            elsif (magnitude_sq < low_threshold_sq) then
                output <= '0';
            end if;
            
            magnitude_sq_debug <= magnitude_sq;
        end if;
    end process trigger_process;
end Behavioral;

