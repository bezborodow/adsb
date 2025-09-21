library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_envelope is
    port (
        clk : in std_logic;
        ce_i : in std_logic; -- Clock enable.
        i_i : in signed(IQ_WIDTH-1 downto 0);
        q_i : in signed(IQ_WIDTH-1 downto 0);
        mag_sq_o : out unsigned(IQ_MAG_SQ_WIDTH-1 downto 0);
        i_o : out signed(IQ_WIDTH-1 downto 0);
        q_o : out signed(IQ_WIDTH-1 downto 0)
    );
end adsb_envelope;

architecture rtl of adsb_envelope is

    -- Clock enable.
    signal ce_c : std_logic := '0';

    -- Magnitude squared calculation.
    signal i_z1, q_z1, i_z2, q_z2, i_z3, q_z3, i_z4, q_z4 : iq_t := (others => '0');
    signal i_sq, q_sq, i_sq_z1, q_sq_z1 : squared_t := (others => '0');
    signal mag_sq_z0 : mag_sq_t := (others => '0');

    -- Output registers.
    signal i_r, q_r : iq_t := (others => '0');
    signal mag_sq_r : mag_sq_t := (others => '0');

begin

    -- Combinatorial signals.
    ce_c <= ce_i;
    mag_sq_o <= mag_sq_r;
    i_o <= i_r;
    q_o <= q_r;

    mag_sq_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_c = '1' then
                -- Calculate magnitude squared.
                -- Use pipeline registers to improve timing for DSP.
                i_z1 <= i_i;
                q_z1 <= q_i;

                -- Second delay. Multiplication. Keep pass-through IQ synchronised.
                i_sq <= i_z1 * i_z1;
                q_sq <= q_z1 * q_z1;
                i_z2 <= i_z1;
                q_z2 <= q_z1;

                -- Another pipeline register after the DSP and before the resize and addition.
                i_sq_z1 <= i_sq;
                q_sq_z1 <= q_sq;
                i_z3 <= i_z2;
                q_z3 <= q_z2;

                -- Third delay. Addition.
                mag_sq_z0 <= resize(unsigned(i_sq_z1), mag_sq_r'length) + resize(unsigned(q_sq_z1), mag_sq_r'length);
                i_z4 <= i_z3;
                q_z4 <= q_z3;

                -- Fourth delay. Output register.
                mag_sq_r <= mag_sq_z0;
                i_r <= i_z4;
                q_r <= q_z4;
            end if;
        end if;
    end process mag_sq_process;
end rtl;
