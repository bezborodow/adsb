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
        i_i : in signed(IQ_WIDTH-1 downto 0);
        q_i : in signed(IQ_WIDTH-1 downto 0);
        gate_i : in std_logic;
        start_i : in std_logic;
        stop_i : in std_logic;
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
    
    signal accumulator_re : signed(ACCUMULATOR_WIDTH-1 downto 0) := (others => '0');
    signal accumulator_im : signed(ACCUMULATOR_WIDTH-1 downto 0) := (others => '0');
    signal accumulation_count : unsigned(integer(ceil(log2(real(ACCUMULATION_LENGTH))))-1 downto 0) := (others => '0');
    signal enable : std_logic := '0';

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
        end if;
    end process delay_process;

    -- Accumulate phasors.
    accumulate_process : process(clk)
        variable phasor_im : signed(IQ_WIDTH*2 downto 0) := (others => '0');
        variable phasor_re : signed(IQ_WIDTH*2 downto 0) := (others => '0');

        procedure reset_procedure is
        begin
            accumulator_re <= (others => '0');
            accumulator_im <= (others => '0');
            accumulation_count <= (others => '0');
            enable <= '0';
            vld <= '0';
        end procedure reset_procedure;
    begin
        if rising_edge(clk) then
            -- Reset on start.
            if start_i = '1' then
                reset_procedure;
                enable <= '1';
            end if;

            if (gate_i = '1') and (gate_z1 = '1') and (enable = '1') then
                if accumulation_count < ACCUMULATION_LENGTH then
                    phasor_re := resize(i_i * i_z1 + q_i * q_z1, phasor_re'length);
                    phasor_im := resize(q_i * i_z1 - i_i * q_z1, phasor_im'length);
                    accumulator_re <= accumulator_re + resize(phasor_re, accumulator_re'length);
                    accumulator_im <= accumulator_im + resize(phasor_im, accumulator_im'length);
                    accumulation_count <= accumulation_count + 1;
                end if;
            end if;

            -- Stop when accumulator is full.
            if accumulation_count = ACCUMULATION_LENGTH-1 then
                vld <= '1';
                enable <= '0';
            end if;

            -- Stop upon external stop signal.
            if stop_i = '1' then
                vld <= '1';
                enable <= '0';
            end if;

            -- Reset when data has been read.
            if vld = '1' and rdy_i = '1' then
                reset_procedure;   
            end if;
        end if;
    end process accumulate_process;
end rtl;
