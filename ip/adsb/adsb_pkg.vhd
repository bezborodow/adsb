library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;

package adsb_pkg is
    -- IQ subtypes.
    constant IQ_WIDTH : positive := 12;
    constant IQ_SQUARED_WIDTH : positive := IQ_WIDTH * 2;
    constant IQ_MAG_SQ_WIDTH : positive := IQ_SQUARED_WIDTH + 1;
    subtype iq_t is signed(IQ_WIDTH-1 downto 0);
    subtype squared_t is signed(IQ_SQUARED_WIDTH-1 downto 0);
    subtype mag_sq_t is unsigned(IQ_MAG_SQ_WIDTH-1 downto 0);

    -- IQ array types.
    type iq_buffer_t is array (natural range <>) of iq_t;
    type mag_sq_buffer_t is array (natural range <>) of mag_sq_t;

    -- General array of integers.
    type adsb_int_array_t is array (natural range <>) of integer;

    -- Preamble detection.
    -- Window energy width is used by the DSP, which can only multiply 18 by 25 bits,
    -- so window energy must be rounded down.
    constant WINDOW_ENERGY_ROUNDED_WIDTH : positive := 18;
    subtype win_energy_t is unsigned (WINDOW_ENERGY_ROUNDED_WIDTH-1 downto 0);

    -- IQ width that comes from the ADC.
    -- This is different from IQ_WIDTH used internally.
    constant ADC_RX_IQ_WIDTH : positive := 16;


    -- Pass in to generics to define the width of an acummulator signal based on the width
    -- of the signal being accumulated and the buffer length.
    function gen_sum_width(input_width : integer; buf_length : integer) return integer;

    --------------------------------------------------------------------------
    -- shrink_right
    --
    -- Utility function to downsize a wide signed/unsigned value by discarding
    -- least-significant bits (LSBs). This is equivalent to performing a
    -- right-shift followed by a resize to the desired output width.
    --
    -- Arguments:
    --   arg        : input vector (signed or unsigned).
    --   target_len : width of the output vector.
    --
    -- Returns:
    --   The input value truncated to 'target_len' bits, keeping the most-
    --   significant bits and discarding the lower (arg'length - target_len).
    --
    -- Example:
    --   est_re_r <= shrink_right(accumulator_re, est_re_r'length);
    --   est_im_r <= shrink_right(accumulator_im, est_im_r'length);
    --
    -- Notes:
    --   * Preserves sign for signed values.
    --   * Useful for fitting large accumulators into smaller result registers.
    --------------------------------------------------------------------------
    function shrink_right(arg : unsigned; target_len : natural) return unsigned;
    function shrink_right(arg : signed;   target_len : natural) return signed;

end package adsb_pkg;

package body adsb_pkg is
    function gen_sum_width(input_width : integer; buf_length : integer) return integer is
    begin
        return input_width + integer(ceil(log2(real(buf_length))));
    end function;

    function shrink_right(arg : unsigned; target_len : natural) return unsigned is
    begin
        return resize(shift_right(arg, arg'length - target_len), target_len);
    end function;

    function shrink_right(arg : signed; target_len : natural) return signed is
    begin
        return resize(shift_right(arg, arg'length - target_len), target_len);
    end function;
end package body adsb_pkg;
