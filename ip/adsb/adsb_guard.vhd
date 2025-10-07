library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_guard is
    generic (
        GUARD_LENGTH : integer := 2
    );
    port (
        clk        : in  std_logic;
        ce_i       : in  std_logic  -- Clock enable.
    );
end adsb_guard;

architecture rtl of adsb_guard is
begin

end rtl;
