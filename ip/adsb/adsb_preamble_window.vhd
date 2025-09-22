library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_preamble_window is
    generic (
        SAMPLES_PER_SYMBOL     : positive;
        PREAMBLE_BUFFER_LENGTH : integer
    );
    port (
        clk : in std_logic;
        ce_i : in std_logic; -- Clock enable.
        i_i : in iq_t;
        q_i : in iq_t;
        mag_sq_i : in mag_sq_t;

        i_o : out iq_t;
        q_o : out iq_t;
        mag_sq_o : out mag_sq_t;
        max_mag_sq_o : out mag_sq_t;
        win_inside_energy_o : out win_energy_t;
        win_outside_energy_o : out win_energy_t;
        all_thresholds_ok_o : out std_logic
    );
end adsb_preamble_window;

architecture rtl of adsb_preamble_window is
    -- Accumulator width for for entire preamble buffer.
    constant BUFFER_ACCUMULATOR_WIDTH : positive := IQ_MAG_SQ_WIDTH + integer(ceil(log2(real(PREAMBLE_BUFFER_LENGTH))));

    -- Accumulator width for a single symbol.
    constant SYMBOL_ACCUMULATOR_WIDTH : positive := IQ_MAG_SQ_WIDTH + integer(ceil(log2(real(SAMPLES_PER_SYMBOL))));

    -- Number of symbols in the preamble.
    constant NUM_SYMBOLS_IN_PREAMBLE : positive := 16;

    -- How many samples the IQ stream is delayed by compared to when the preamble is detected.
    constant PIPELINE_DELAY : positive := 6;

    -- Where each pulse in the preamble starts.
    -- There are four pulses in the preamble of an ADS-B message.
    constant PREAMBLE_POSITION : adsb_int_array_t := (0, 2, 7, 9);

    -- Buffers for magnitude-squared and IQ samples.
    -- Magnitude buffer length is as long as the number of samples in the
    -- preamble and is used for preamble detection.
    -- The IQ buffer is for timing and is as long as the number of delay clock
    -- cycles of this component.
    subtype mag_sq_buffer_index_t is natural range 0 to PREAMBLE_BUFFER_LENGTH-1;
    signal mag_sq_buf_shift_reg : mag_sq_buffer_t(0 to PREAMBLE_BUFFER_LENGTH-1) := (others => (others => '0'));

    -- Symbol window register.
    type symbol_t is array (natural range <>) of mag_sq_buffer_t(0 to SAMPLES_PER_SYMBOL-1);
    signal symbol_reg : symbol_t(0 to NUM_SYMBOLS_IN_PREAMBLE-1) := (others => (others => (others => '0')));

    -- Accumulated buffer energy.
    subtype buffer_energy_t is unsigned(BUFFER_ACCUMULATOR_WIDTH-1 downto 0);

    -- Symbol energy.
    -- This is smaller in width than buffer energy.
    subtype symbol_energy_t is unsigned(SYMBOL_ACCUMULATOR_WIDTH-1 downto 0);
    type symbol_energy_array_t is array (natural range <>) of symbol_energy_t;
    signal symbol_energy_a : symbol_energy_array_t(0 to NUM_SYMBOLS_IN_PREAMBLE-1) := (others => (others => '0'));
    signal symbol_energy_a_z1 : symbol_energy_array_t(0 to NUM_SYMBOLS_IN_PREAMBLE-1) := (others => (others => '0'));

    -- Maximum magnitude squared.
    type symbol_maximum_array_t is array (natural range <>) of mag_sq_t;
    signal symbol_max_a : symbol_maximum_array_t(0 to 3) := (others => (others => '0'));

    -- Delay pipeline for IQ.
    signal i_buf_reg, q_buf_reg : iq_buffer_t(0 to PIPELINE_DELAY-1) := (others => (others => '0'));

    -- Stage 4 registered signals.
    signal stage4_max0_r               : mag_sq_t := (others => '0');
    signal stage4_max1_r               : mag_sq_t := (others => '0');
    signal stage4_max_mag_sq_r         : mag_sq_t := (others => '0');
    signal stage4_win_inside_energy_r  : buffer_energy_t := (others => '0');
    signal stage4_win_outside_energy_r : buffer_energy_t := (others => '0');
    signal stage4_symbol_energy_a_r    : symbol_energy_array_t(0 to NUM_SYMBOLS_IN_PREAMBLE-1) := (others => (others => '0'));

    -- Stage 5 registered signals.
    signal stage5_max_mag_sq_r         : mag_sq_t := (others => '0');
    signal stage5_win_inside_energy_r  : win_energy_t := (others => '0'); -- Shrink (resize) at stage 5.
    signal stage5_win_outside_energy_r : win_energy_t := (others => '0');
    signal stage5_win_total_energy_r   : buffer_energy_t := (others => '0');
    signal stage5_symbol_energy_a_r    : symbol_energy_array_t(0 to NUM_SYMBOLS_IN_PREAMBLE-1) := (others => (others => '0'));

    -- Output registers.
    signal win_inside_energy_r : win_energy_t := (others => '0');
    signal win_outside_energy_r : win_energy_t := (others => '0');
    signal max_mag_sq_r : mag_sq_t := (others => '0');
    signal i_r, q_r : iq_t := (others => '0');
    signal mag_sq_r : unsigned(IQ_MAG_SQ_WIDTH-1 downto 0) := (others => '0');
    signal all_thresholds_ok_r : std_logic := '0';

    -- Finds the max of four samples from the symbol.
    -- This does not check every symbol, otherwise timing would fail,
    -- and a more elaborate algorithmn would be required.
    function find_max_in_symbol(symbol_v : mag_sq_buffer_t) return mag_sq_t is
        -- Need to compare in a tree. Compare first two pairs,
        -- then second pair. Choose four samples, evenly spaced in the symbol.
        constant SAMPLE_INDICES : adsb_int_array_t := (
            SAMPLES_PER_SYMBOL / 8,
            SAMPLES_PER_SYMBOL / 8 + SAMPLES_PER_SYMBOL / 4,
            SAMPLES_PER_SYMBOL / 8 + 2 * SAMPLES_PER_SYMBOL / 4,
            SAMPLES_PER_SYMBOL / 8 + 3 * SAMPLES_PER_SYMBOL / 4
        );

        -- First stage comparison.
        variable max0_0_v, max0_1_v, max1_0_v, max1_1_v : mag_sq_t := (others => '0');

        -- Second stage comparison.
        variable max0_v, max1_v : mag_sq_t := (others => '0');
    begin
        max0_0_v := symbol_v(SAMPLE_INDICES(0));
        max0_1_v := symbol_v(SAMPLE_INDICES(1));
        max1_0_v := symbol_v(SAMPLE_INDICES(2));
        max1_1_v := symbol_v(SAMPLE_INDICES(3));

        -- First stage.
        if max0_0_v > max0_1_v then
            max0_v := max0_0_v;
        else
            max0_v := max0_1_v;
        end if;
        if max1_0_v > max1_1_v then
            max1_v := max1_0_v;
        else
            max1_v := max1_1_v;
        end if;

        -- Second stage.
        if max0_v > max1_v then
            return max0_v;
        end if;

        return max1_v;
    end function;

begin
    -- Combinatorial signals.
    i_o <= i_r;
    q_o <= q_r;
    mag_sq_o <= mag_sq_r;

    -- Drive output port from registers.
    win_inside_energy_o <= win_inside_energy_r;
    win_outside_energy_o <= win_outside_energy_r;
    max_mag_sq_o <= max_mag_sq_r;
    all_thresholds_ok_o <= all_thresholds_ok_r;

    stage1_buffer_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                -- Append most recently arrived sample onto the end of the shift register.
                mag_sq_buf_shift_reg(PREAMBLE_BUFFER_LENGTH-1) <= mag_sq_i;
                i_buf_reg(PIPELINE_DELAY-1) <= i_i;
                q_buf_reg(PIPELINE_DELAY-1) <= q_i;
                
                -- Pipeline shift registers for IQ and magnitude squared envelope.
                for i in 0 to PREAMBLE_BUFFER_LENGTH-2 loop
                    mag_sq_buf_shift_reg(i) <= mag_sq_buf_shift_reg(i+1);
                end loop;
                for i in 0 to PIPELINE_DELAY-2 loop
                    i_buf_reg(i) <= i_buf_reg(i+1);
                    q_buf_reg(i) <= q_buf_reg(i+1);
                end loop;
            end if;
        end if;
    end process stage1_buffer_process;

    -- Register symbol windows from the buffer before passing into the DSP.
    stage2_symbol_register_process : process(clk)
        variable buf_shift_idx : mag_sq_buffer_index_t := 0;
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                for i in 0 to NUM_SYMBOLS_IN_PREAMBLE-1 loop
                    for j in 0 to SAMPLES_PER_SYMBOL-1 loop
                        buf_shift_idx := i * SAMPLES_PER_SYMBOL + j;
                        symbol_reg(i)(j) <= mag_sq_buf_shift_reg(buf_shift_idx);
                    end loop;
                end loop;
            end if;
        end if;
    end process stage2_symbol_register_process;

    -- Find energy per each symbol window.
    stage3_symbol_energy_process : process(clk)
        variable sym_accumulators : symbol_energy_array_t(0 to NUM_SYMBOLS_IN_PREAMBLE-1) := (others => (others => '0'));
        variable sample_v : mag_sq_t := (others => '0');
        variable accum_v : symbol_energy_t := (others => '0');
        variable k : integer range 0 to 3 := 0;
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                -- Compute energy in each symbol window.
                -- Zero local accumulators.
                for i in 0 to NUM_SYMBOLS_IN_PREAMBLE-1 loop
                    sym_accumulators(i) := (others => '0');
                end loop;

                -- For each symbol window.
                k := 0;
                for i in 0 to NUM_SYMBOLS_IN_PREAMBLE-1 loop
                    -- Sum energy.
                    for j in 0 to SAMPLES_PER_SYMBOL-1 loop
                        sample_v := symbol_reg(i)(j);
                        accum_v := resize(sample_v, accum_v'length);
                        sym_accumulators(i) := sym_accumulators(i) + accum_v;
                    end loop;
                    symbol_energy_a(i) <= sym_accumulators(i);

                    -- Find maximum value of envelope.
                    -- Find max within each of the four high symbols first.
                    -- Later, this will be narrowed down further in another clock cycle.
                    if i = 0 or i = 2 or i = 7 or i = 9 then

                        -- This can fail timing, so do not check every sample.
                        symbol_max_a(k) <= find_max_in_symbol(symbol_reg(i));

                        if k < 3 then
                            k := k + 1;
                        end if;
                    end if;
                end loop;
            end if;
        end if;
    end process stage3_symbol_energy_process;

    -- Find energy inside and outside preamble window.
    stage4_window_energy_process : process(clk)
        variable sum_inside_v : buffer_energy_t := (others => '0');
        variable sum_outside_v : buffer_energy_t := (others => '0');
        variable max_mag_sq_v : mag_sq_t := (others => '0');
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                sum_inside_v := (others => '0');
                sum_outside_v := (others => '0');

                -- For each symbol window.
                for i in 0 to NUM_SYMBOLS_IN_PREAMBLE-1 loop

                    -- Register z1 before passing to DSP.
                    symbol_energy_a_z1(i) <= symbol_energy_a(i);

                    -- Summation of window energy.
                    if i = 0 or i = 2 or i = 7 or i = 9 then
                        sum_inside_v := sum_inside_v + resize(symbol_energy_a_z1(i), sum_inside_v'length);
                    else
                        sum_outside_v := sum_outside_v + resize(symbol_energy_a_z1(i), sum_outside_v'length);
                    end if;
                end loop;

                -- Find maximum each of the four symbols.
                -- This takes two cycles.
                -- First two pairs to find maximum.
                if symbol_max_a(0) > symbol_max_a(1) then
                    stage4_max0_r <= symbol_max_a(0);
                else
                    stage4_max0_r <= symbol_max_a(1);
                end if;

                if symbol_max_a(2) > symbol_max_a(3) then
                    stage4_max1_r <= symbol_max_a(2);
                else
                    stage4_max1_r <= symbol_max_a(3);
                end if;

                -- Last pair to find maximum.
                if stage4_max0_r > stage4_max1_r then
                    max_mag_sq_v := stage4_max0_r;
                else
                    max_mag_sq_v := stage4_max1_r;
                end if;

                -- Pass to next stage.
                stage4_max_mag_sq_r <= max_mag_sq_v;
                stage4_win_inside_energy_r <= sum_inside_v;
                stage4_win_outside_energy_r <= sum_outside_v;
                stage4_symbol_energy_a_r <= symbol_energy_a_z1;
            end if;
        end if;
    end process stage4_window_energy_process;

    -- Find energy inside and outside preamble window.
    stage5_total_energy_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                stage5_max_mag_sq_r <= stage4_max_mag_sq_r;
                stage5_win_inside_energy_r <= shrink_right(stage4_win_inside_energy_r, win_energy_t'length);
                stage5_win_outside_energy_r <= shrink_right(stage4_win_outside_energy_r, win_energy_t'length);
                stage5_win_total_energy_r <= stage4_win_inside_energy_r + stage4_win_outside_energy_r;
                stage5_symbol_energy_a_r <= stage4_symbol_energy_a_r;
            end if;
        end if;
    end process stage5_total_energy_process;

    -- Threshold for each preamble high symbol.
    stage6_thresholds_process : process(clk)
        variable symhigh_energy_v : symbol_energy_array_t(0 to 3) := (others => (others => '0'));
        variable total_energy_v, threshold_v : buffer_energy_t := (others => '0');

        variable all_thresholds_ok_v : std_logic := '0';
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                all_thresholds_ok_v := '1';
                total_energy_v := stage5_win_total_energy_r;

                -- The threshold applies to all four preamble high symbols.
                -- The threshold is relative to total energy in the preamble buffer.
                -- Threshold should be slightly less than 1/4 of total energy to trigger a detection.
                -- Therefore, use multiplication followed by shift right by 4 to achieve 3/16.
                -- The threshold ensures that each high symbol is getting roughly equal amounts of energy spread across it.
                threshold_v := resize((total_energy_v * to_unsigned(3, total_energy_v'length+2)) srl 4, total_energy_v'length);
                for i in PREAMBLE_POSITION'range loop
                    symhigh_energy_v(i) := stage5_symbol_energy_a_r(PREAMBLE_POSITION(i));
                    if resize(symhigh_energy_v(i), threshold_v'length) <= threshold_v then
                        all_thresholds_ok_v := '0';
                    end if;
                end loop;

                win_inside_energy_r <= stage5_win_inside_energy_r;
                win_outside_energy_r <= stage5_win_outside_energy_r;
                max_mag_sq_r <= stage5_max_mag_sq_r;
                all_thresholds_ok_r <= all_thresholds_ok_v;
            end if;
        end if;
    end process stage6_thresholds_process;

    -- Pass-through signals delayed against the pipeline delay.
    -- These signals are useful for keeping everything synchronised, since
    -- preamble detection introduces delay.
    delay_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                i_r <= i_buf_reg(0);
                q_r <= q_buf_reg(0);
                mag_sq_r <= mag_sq_buf_shift_reg(PREAMBLE_BUFFER_LENGTH - PIPELINE_DELAY);
            end if;
        end if;
    end process delay_process;
end rtl;
