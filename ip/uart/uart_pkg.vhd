library ieee;                        
use ieee.std_logic_1164.all;         
use ieee.numeric_std.all;            

package uart_pkg is
    function uart_ascii_hex(
        n : std_logic_vector(3 downto 0)
    ) return std_logic_vector;

    type uart_byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);
end package uart_pkg;

package body uart_pkg is
    type hex_table_t is array (0 to 15) of std_logic_vector(7 downto 0);
    constant hex_table : hex_table_t := (
        x"30", -- 0
        x"31", -- 1
        x"32", -- 2
        x"33", -- 3
        x"34", -- 4
        x"35", -- 5
        x"36", -- 6
        x"37", -- 7
        x"38", -- 8
        x"39", -- 9
        x"41", -- A
        x"42", -- B
        x"43", -- C
        x"44", -- D
        x"45", -- E
        x"46"  -- F
    );

    function uart_ascii_hex(
        n : std_logic_vector(3 downto 0)
    ) return std_logic_vector is
    begin
        return hex_table(to_integer(unsigned(n)));
    end function uart_ascii_hex;
end package body uart_pkg;
