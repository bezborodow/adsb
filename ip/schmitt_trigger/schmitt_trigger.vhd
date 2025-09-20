-- Schmitt Trigger
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity schmitt_trigger is
    generic (
        SIGNAL_WIDTH : integer := 25
    );
    port (
        clk : in std_logic;
        ce_i : in std_logic;
        schmitt_i : in unsigned(SIGNAL_WIDTH-1 downto 0) := (others => '0');
        high_threshold_i : in unsigned(SIGNAL_WIDTH-1 downto 0) := (others => '0');
        low_threshold_i : in unsigned(SIGNAL_WIDTH-1 downto 0) := (others => '0');

        schmitt_o : out std_logic
    );
end schmitt_trigger;

architecture rtl of schmitt_trigger is
    signal schmitt_c : std_logic := '0';
    signal ce_c : std_logic := '0';
begin
    ce_c <= ce_i;
    schmitt_o <= schmitt_c;

    trigger_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_c = '1' then
                -- TODO Think about registering this comparison if timing fails.
                if (schmitt_i > high_threshold_i) then
                    schmitt_c <= '1';
                elsif (schmitt_i < low_threshold_i) then
                    schmitt_c <= '0';
                end if;
            end if;
        end if;
    end process trigger_process;
end rtl;
