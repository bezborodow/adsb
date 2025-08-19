-- Frequency Estimator

library ieee;
use ieee.std_logic_1164.all;

use ieee.numeric_std.all;
use ieee.math_real.all;

entity freq_est is
    generic (
        IQ_WIDTH : integer := 12;
        ACCUMULATION_LENGTH : integer := 1024
    );
    port (
        clk : in std_logic;
        en_i : in std_logic;
        i_i : in signed(IQ_WIDTH-1 downto 0);
        q_i : in signed(IQ_WIDTH-1 downto 0);
        gate_i : in std_logic;
        vld_o : out std_logic;
        rdy_i : in std_logic;
        freq_o : out signed(15 downto 0)
    );
end freq_est;

architecture rtl of freq_est is
    constant ACCUMULATOR_WIDTH : integer := IQ_WIDTH*2 + 1 + integer(ceil(log2(real(ACCUMULATION_LENGTH))));

    signal i_z1 : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal q_z1 : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal gate_z1 : std_logic := '0';
    signal en_z1 : std_logic := '0';
    
    signal accumulator_re : signed(ACCUMULATOR_WIDTH-1 downto 0) := (others => '0');
    signal accumulator_im : signed(ACCUMULATOR_WIDTH-1 downto 0) := (others => '0');

    signal vld : std_logic := '0';

begin
    vld_o <= vld;

    -- Delayed signals.
    delay_process : process(clk)
    begin
        if rising_edge(clk) then
            i_z1 <= i_i;
            q_z1 <= q_i;
            gate_z1 <= gate_i;
            en_z1 <= en_i;
        end if;
    end process delay_process;

    -- Accumulate phasors.
    accumulate_process : process(clk)
        variable phasor_im : signed(IQ_WIDTH*2 downto 0) := (others => '0');
        variable phasor_re : signed(IQ_WIDTH*2 downto 0) := (others => '0');
    begin
        if rising_edge(clk) then
            if (gate_i = '1') and (gate_z1 = '1') then
                phasor_im := resize(i_i * q_z1 - q_i * i_z1, phasor_im'length);
                phasor_re := resize(i_i * i_z1 + q_i * q_z1, phasor_re'length);
                accumulator_re <= accumulator_re + resize(phasor_re, accumulator_re'length);
                accumulator_im <= accumulator_im + resize(phasor_re, accumulator_re'length);
            end if;
            vld <= not vld;
        end if;
    end process accumulate_process;
end rtl;
