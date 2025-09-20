library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity preamble_window is
    generic (
        SAMPLES_PER_SYMBOL     : integer := ADSB_DEFAULT_SAMPLES_PER_SYMBOL;
        IQ_WIDTH               : integer := ADSB_DEFAULT_IQ_WIDTH;
        MAGNITUDE_WIDTH        : integer := ADSB_DEFAULT_IQ_WIDTH * 2 + 1;
        BUFFER_LENGTH          : integer := ADSB_DEFAULT_PREAMBLE_BUFFER_LENGTH;
        --CORRELATION_WIDTH      : integer := (ADSB_DEFAULT_IQ_WIDTH * 2 + 1) + integer(ceil(log2(real(ADSB_DEFAULT_PREAMBLE_BUFFER_LENGTH))));
        PREAMBLE_POSITION1     : integer := 20;
        PREAMBLE_POSITION2     : integer := 70;
        PREAMBLE_POSITION3     : integer := 90
    );
    port (
        clk : in std_logic;
        ce_i : in std_logic; -- Clock enable.
        i_i : in signed(IQ_WIDTH-1 downto 0);
        q_i : in signed(IQ_WIDTH-1 downto 0);
        mag_sq_i : in unsigned(MAGNITUDE_WIDTH-1 downto 0);

        i_o : out signed(IQ_WIDTH-1 downto 0);
        q_o : out signed(IQ_WIDTH-1 downto 0);
        mag_sq_o : out unsigned(MAGNITUDE_WIDTH-1 downto 0);
        win_inside_energy_o : out unsigned(MAGNITUDE_WIDTH-1 downto 0);
        win_outside_energy_o : out unsigned(MAGNITUDE_WIDTH-1 downto 0)
    );
end preamble_window;

architecture rtl of preamble_window is
    -- Clock enable.
    signal ce_c : std_logic := '0';

    -- Accumulator width for window correlation.
    constant CORRELATION_WIDTH : positive := MAGNITUDE_WIDTH + integer(ceil(log2(real(BUFFER_LENGTH))));

    -- Number of symbols in the preamble.
    constant NUM_SYMBOLS_IN_PREAMBLE : positive := 16;

    -- How many samples the IQ stream is delayed by compared to when the preamble is detected.
    constant PIPELINE_DELAY : positive := 6;

    -- Combinatorial port signals.
    signal i_c, q_c : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal mag_sq_c : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal win_inside_energy_c : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal win_outside_energy_c : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');

    -- Where each pulse in the preamble starts.
    -- There are four pulses in the preamble of an ADS-B message.
    constant PREAMBLE_POSITION : adsb_int_array_t := (
        0,
        PREAMBLE_POSITION1,
        PREAMBLE_POSITION2,
        PREAMBLE_POSITION3
    );

    -- Energy in each pulse window.
    constant WINDOW_WIDTH : integer := (IQ_WIDTH*2) + integer(ceil(log2(real(SAMPLES_PER_SYMBOL))));
    type symbol_energy_t is array (0 to PREAMBLE_POSITION'length-1) of unsigned(WINDOW_WIDTH-1 downto 0);
    signal sym_energy : symbol_energy_t := (others => (others => '0'));

    -- Buffers for magnitude-squared and IQ samples.
    -- Magnitude buffer length is as long as the number of samples in the
    -- preamble and is used for preamble detection.
    -- The IQ buffer is for timing and is as long as the number of delay clock
    -- cycles of this component.
    subtype mag_sample_t is unsigned(MAGNITUDE_WIDTH-1 downto 0);
    type mag_sq_buffer_t is array (natural range <>) of mag_sample_t;
    signal shift_reg : mag_sq_buffer_t(0 to BUFFER_LENGTH-1) := (others => (others => '0'));

    -- Window register.
    type window_t is array (natural range <>) of mag_sq_buffer_t(0 to SAMPLES_PER_SYMBOL-1);
    signal window_reg : window_t(0 to NUM_SYMBOLS_IN_PREAMBLE-1) := (others => (others => (others => '0')));

    -- Delay pipeline for IQ.
    type iq_buffer_t is array (natural range <>) of signed(IQ_WIDTH-1 downto 0);
    signal i_reg : iq_buffer_t(0 to PIPELINE_DELAY-1) := (others => (others => '0'));
    signal q_reg : iq_buffer_t(0 to PIPELINE_DELAY-1) := (others => (others => '0'));

    -- Signals for computation of correlation windows.
    signal correlation : signed(CORRELATION_WIDTH-1 downto 0) := (others => '0');
    signal energy : unsigned(CORRELATION_WIDTH-1 downto 0) := (others => '0');

    function max_over_preamble(sr : mag_sq_buffer_t) return unsigned is
        variable m       : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
        variable s       : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
        variable idx_sym : integer;
    begin
        for i in 0 to PREAMBLE_POSITION'length-1 loop
            for ii in 0 to SAMPLES_PER_SYMBOL-1 loop
                idx_sym := PREAMBLE_POSITION(i) + ii;
                if idx_sym >= sr'low and idx_sym <= sr'high then
                    s := resize(sr(idx_sym), m'length);
                    if s > m then
                        m := s;
                    end if;
                else
                    report "max_over_preamble: idx_sym out of range" severity warning;
                end if;
            end loop;
        end loop;

        return m;
    end function;

begin
    -- Combinatorial signals.
    ce_c <= ce_i;
    i_o <= i_c;
    q_o <= q_c;
    mag_sq_o <= mag_sq_c;

    buffer_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_c = '1' then
                -- Append most recently arrived sample onto the end of the shift register.
                shift_reg(BUFFER_LENGTH-1) <= mag_sq_i;
                i_reg(PIPELINE_DELAY-1) <= i_i;
                q_reg(PIPELINE_DELAY-1) <= q_i;
                
                -- Shift register.
                for i in 0 to BUFFER_LENGTH-2 loop
                    shift_reg(i) <= shift_reg(i+1);
                end loop;
                for i in 0 to PIPELINE_DELAY-2 loop
                    i_reg(i) <= i_reg(i+1);
                    q_reg(i) <= q_reg(i+1);
                end loop;
            end if;
        end if;
    end process buffer_process;

    -- Register symbol windows from the buffer before passing into the DSP.
    symbol_register_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_c = '1' then
                for i in 0 to NUM_SYMBOLS_IN_PREAMBLE-1 loop
                    for j in 0 to SAMPLES_PER_SYMBOL-1 loop
                        window_reg(i)(j) <= shift_reg(i * SAMPLES_PER_SYMBOL + j);
                    end loop;
                end loop;
            end if;
        end if;
    end process symbol_register_process;

    symbol_energy_process : process(clk)
        variable sum_energy : unsigned(CORRELATION_WIDTH-1 downto 0);
        variable tmp_sym : symbol_energy_t;
        variable idx_sym : integer;
    begin
        if rising_edge(clk) then
            if ce_c = '1' then
                -- Zero local accumulators.
                for j in 0 to PREAMBLE_POSITION'length-1 loop
                    tmp_sym(j) := (others => '0');
                end loop;

                -- Sum each symbol bin from the shift_reg.
                for i in 0 to PREAMBLE_POSITION'length-1 loop
                    for ii in 0 to SAMPLES_PER_SYMBOL-1 loop
                        idx_sym := PREAMBLE_POSITION(i) + ii;
                        tmp_sym(i) := tmp_sym(i) + resize(shift_reg(idx_sym), tmp_sym(i)'length);
                    end loop;
                end loop;

                -- Write back to signals.
                for j in 0 to PREAMBLE_POSITION'length-1 loop
                    sym_energy(j) <= tmp_sym(j);
                end loop;

                sum_energy := (others => '0');
                for i in 0 to BUFFER_LENGTH-1 loop
                    sum_energy := sum_energy + resize(shift_reg(BUFFER_LENGTH-i-1), sum_energy'length);
                end loop;
                energy <= sum_energy;

            end if;
        end if;
    end process symbol_energy_process;

    -- Passthrough signals delayed against the pipeline delay.
    -- These signals are useful for keeping everything synchronised, since
    -- preamble detection introduces delay.
    delay_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_c = '1' then
                i_c <= i_reg(0);
                q_c <= q_reg(0);
                mag_sq_c <= shift_reg(BUFFER_LENGTH - PIPELINE_DELAY);
            end if;
        end if;
    end process delay_process;
end rtl;
