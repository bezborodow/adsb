library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_envelope is
    generic (
        IQ_WIDTH              : integer := ADSB_DEFAULT_IQ_WIDTH;
        MAGNITUDE_WIDTH       : integer := ADSB_DEFAULT_IQ_WIDTH * 2 + 1
    );
    port (
        clk : in std_logic;
        ce_i : in std_logic; -- Clock enable.
        i_i : in signed(IQ_WIDTH-1 downto 0);
        q_i : in signed(IQ_WIDTH-1 downto 0);
        mag_sq_o : out unsigned(MAGNITUDE_WIDTH-1 downto 0);
        i_o : out signed(IQ_WIDTH-1 downto 0);
        q_o : out signed(IQ_WIDTH-1 downto 0)
    );
end adsb_envelope;

architecture rtl of adsb_envelope is
    -- Clock enable.
    signal ce_c : std_logic := '0';

    -- Magnitude squared calculation.
    signal i_r, q_r, i_z2, q_z2, i_z3, q_z3, i_z4, q_z4 : signed(IQ_WIDTH-1 downto 0);
    signal i_sq, q_sq : signed(IQ_WIDTH*2-1 downto 0);
    signal mag_sq_r, mag_sq_z1 : unsigned(MAGNITUDE_WIDTH-1 downto 0);
begin
    -- Combinatorial signals.
    ce_c <= ce_i;
    mag_sq_o <= mag_sq_z1;
    i_o <= i_z4;
    q_o <= q_z4;

    mag_sq_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_c = '1' then
                -- Calculate magnitude squared.
                -- Use registers to improve timing for DSP.
                i_r <= i_i;
                q_r <= q_i;
                
                -- Second delay. Multiplication. Keep pass-through IQ synchronised.
                i_sq <= i_r * i_r;
                q_sq <= q_r * q_r;
                i_z2 <= i_r;
                q_z2 <= q_r;

                -- Third delay. Addition.
                mag_sq_r <= resize(unsigned(i_sq), mag_sq_r'length) + resize(unsigned(q_sq), mag_sq_r'length);
                i_z3 <= i_z2;
                q_z3 <= q_z2;

                -- Fourth delay. Output register.
                mag_sq_z1 <= mag_sq_r;
                i_z4 <= i_z3;
                q_z4 <= q_z3;
            end if;
        end if;
    end process mag_sq_process;
end rtl;
