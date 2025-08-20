-- Schmitt Trigger
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity schmitt_trigger is
    generic (
        SIGNAL_WIDTH : integer := 25
    );
    port (
        magnitude_sq : in unsigned(SIGNAL_WIDTH-1 downto 0) := (others => '0');
        high_threshold_i : in unsigned(SIGNAL_WIDTH-1 downto 0) := (others => '0');
        low_threshold_i : in unsigned(SIGNAL_WIDTH-1 downto 0) := (others => '0');
        output : out std_logic;
        ce : in std_logic := '0'; -- Clock enable.
        clk : in std_logic
    );
end schmitt_trigger;

architecture rtl of schmitt_trigger is
begin
    trigger_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce then
                if (magnitude_sq > high_threshold_i) then
                    output <= '1';
                elsif (magnitude_sq < low_threshold_i) then
                    output <= '0';
                end if;
            else
                output <= '0';
            end if;
        end if;
    end process trigger_process;
end rtl;
