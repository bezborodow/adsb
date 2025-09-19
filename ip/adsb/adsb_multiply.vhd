library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_multiply is
    generic (
        IQ_WIDTH : integer := ADSB_DEFAULT_IQ_WIDTH
    );
    port (
        clk : in std_logic;
        ce_i : in std_logic; -- Clock enable.
        i0_i : in signed(IQ_WIDTH-1 downto 0);
        q0_i : in signed(IQ_WIDTH-1 downto 0);
        i1_i : in signed(IQ_WIDTH-1 downto 0);
        q1_i : in signed(IQ_WIDTH-1 downto 0);
        i_o : out signed(IQ_WIDTH-1 downto 0);
        q_o : out signed(IQ_WIDTH-1 downto 0)
    );
end adsb_multiply;

architecture Behavioral of adsb_multiply is
    -- Clock enable.
    signal ce_s : std_logic := '0';

begin
    ce_s <= ce_i;

    mixer_process : process(clk)
        variable a : signed(IQ_WIDTH-1 downto 0) := 0;
        variable b : signed(IQ_WIDTH-1 downto 0) := 0;
        variable c : signed(IQ_WIDTH-1 downto 0) := 0;
        variable d : signed(IQ_WIDTH-1 downto 0) := 0;
        variable re : signed(IQ_WIDTH*2 downto 0) := 0;
        variable im : signed(IQ_WIDTH*2 downto 0) := 0;
    begin
        if rising_edge(clk) then
            if ce_s= '1' then
                a := i0_i;
                b := q0_i;
                c := i1_i;
                d := q1_i;

                -- Complex multiply.
                -- (a + bj)(c + dj)
                re := a * c - b * d; -- In-phase / real part.
                im := a * d + b * c; -- Quadrature / imaginary part.

                i_o <= resize(shift_right(re, re'length - i_o'length), i_o'length);
                q_o <= resize(shift_right(im, im'length - q_o'length), q_o'length);
            end if;
        end if;
    end process mixer_process;
end Behavioral;
