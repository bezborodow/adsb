library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_tapped_buffer is
    generic (
        PREAMBLE_BUFFER_LENGTH : integer
    );
    port (
        clk        : in  std_logic;
        ce_i       : in  std_logic;  -- Clock enable.
        mag_sq_i   : in  mag_sq_t

        -- TODO Taps.
    );
end adsb_tapped_buffer;

architecture rtl of adsb_tapped_buffer is
begin

end rtl;
