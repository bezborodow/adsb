library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_rolling_sum is
    generic (
        ROLLING_BUFFER_LENGTH : integer
    );
    port (
        clk        : in  std_logic;
        ce_i       : in  std_logic;  -- Clock enable.
        incoming_i : in  mag_sq_t;   -- New sample.
        outgoing_i : in  mag_sq_t;   -- Old sample leaving the window.
        sum_o      : out mag_sq_t    -- Current rolling sum.
    );
end adsb_rolling_sum;

architecture rtl of adsb_rolling_sum is
begin

end rtl;
