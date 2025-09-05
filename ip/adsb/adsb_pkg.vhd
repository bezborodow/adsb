library ieee;                        
use ieee.std_logic_1164.all;         
use ieee.numeric_std.all;            

package adsb_pkg is
    type adsb_int_array_t is array (natural range <>) of integer;

    -- Default settings for testbenches at 20 MSPS.
    constant ADSB_DEFAULT_IQ_WIDTH : integer := 12;
    constant ADSB_DEFAULT_SAMPLES_PER_SYMBOL : integer := 10;
    constant ADSB_DEFAULT_PREAMBLE_BUFFER_LENGTH : integer := 16 * ADSB_DEFAULT_SAMPLES_PER_SYMBOL;
    constant ADSB_DEFAULT_PREAMBLE_POSITION : adsb_int_array_t := (0, 20, 70, 90);

    -- Settings for ADRV9364-Z7020 at 61.44 MSPS.
    constant ADSB_IQ_WIDTH : integer := 12;
    constant ADSB_SAMPLES_PER_SYMBOL : integer := 31;
    constant ADSB_PREAMBLE_BUFFER_LENGTH : integer := 492;
    constant ADSB_PREAMBLE_POSITION : adsb_int_array_t := (0, 61, 215, 276);

end package adsb_pkg;

package body adsb_pkg is
end package body adsb_pkg;
