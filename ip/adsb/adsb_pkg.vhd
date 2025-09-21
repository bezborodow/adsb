library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package adsb_pkg is
    constant IQ_WIDTH : positive := 12;
    constant IQ_SQUARED_WIDTH : positive := IQ_WIDTH * 2;
    constant IQ_MAG_SQ_WIDTH : positive := IQ_SQUARED_WIDTH + 1;

    -- IQ subtypes.
    subtype iq_t is signed(IQ_WIDTH-1 downto 0);
    subtype squared_t is signed(IQ_SQUARED_WIDTH-1 downto 0);
    subtype mag_sq_t is unsigned(IQ_MAG_SQ_WIDTH-1 downto 0);

    -- IQ array types.
    type iq_buffer_t is array (natural range <>) of iq_t;
    type mag_sq_buffer_t is array (natural range <>) of mag_sq_t;

    -- General array of integers.
    type adsb_int_array_t is array (natural range <>) of integer;

    -- IQ width that comes from the ADC.
    -- This is different from IQ_WIDTH used internally.
    constant ADC_RX_IQ_WIDTH : positive := 16;

end package adsb_pkg;

package body adsb_pkg is
end package body adsb_pkg;
