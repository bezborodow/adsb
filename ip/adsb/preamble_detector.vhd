library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity preamble_detector is
    generic (
        SAMPLES_PER_SYMBOL    : integer := ADSB_DEFAULT_SAMPLES_PER_SYMBOL;
        IQ_WIDTH              : integer := ADSB_DEFAULT_IQ_WIDTH;
        MAGNITUDE_WIDTH       : integer := ADSB_DEFAULT_IQ_WIDTH * 2 + 1;
        BUFFER_LENGTH         : integer := ADSB_DEFAULT_PREAMBLE_BUFFER_LENGTH;
        PREAMBLE_POSITION1     : integer := 20;
        PREAMBLE_POSITION2     : integer := 70;
        PREAMBLE_POSITION3     : integer := 90
    );
    port (
        clk : in std_logic;
        ce_i : in std_logic; -- Clock enable.
        i_i : in signed(IQ_WIDTH-1 downto 0);
        q_i : in signed(IQ_WIDTH-1 downto 0);
        detect_o : out std_logic := '0';
        mag_sq_o : out unsigned(MAGNITUDE_WIDTH-1 downto 0);
        high_threshold_o : out unsigned(MAGNITUDE_WIDTH-1 downto 0);
        low_threshold_o : out unsigned(MAGNITUDE_WIDTH-1 downto 0);
        i_o : out signed(IQ_WIDTH-1 downto 0);
        q_o : out signed(IQ_WIDTH-1 downto 0)
    );
end preamble_detector;

architecture rtl of preamble_detector is
    -- Clock enable.
    signal ce_c : std_logic := '0';

    -- How many samples the IQ stream is delayed by compared to when the preamble is detected.
    -- TODO Write testbench to ensure that pipeline delay is correct.
    constant PIPELINE_DELAY : integer := 6;

    --constant BUFFER_LENGTH : integer := SAMPLES_PER_SYMBOL * BUFFER_SYMBOL_LENGTH;
    constant CORRELATION_WIDTH : integer := MAGNITUDE_WIDTH + integer(ceil(log2(real(BUFFER_LENGTH))));

    -- Combinatorial port signals.
    signal i_c, q_c : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal mag_sq_c : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');

    -- Envelope detector signals. IQ and magnitude squared.
    signal env_i, env_q : signed(IQ_WIDTH-1 downto 0);
    signal env_mag_sq : unsigned(MAGNITUDE_WIDTH-1 downto 0);

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
    type mag_sq_buffer_t is array (natural range <>) of unsigned(MAGNITUDE_WIDTH-1 downto 0);
    type iq_buffer_t is array (natural range <>) of signed(IQ_WIDTH-1 downto 0);
    signal shift_reg : mag_sq_buffer_t(0 to BUFFER_LENGTH-1) := (others => (others => '0'));
    signal i_reg : iq_buffer_t(0 to PIPELINE_DELAY-1) := (others => (others => '0'));
    signal q_reg : iq_buffer_t(0 to PIPELINE_DELAY-1) := (others => (others => '0'));

    -- Signals for computation of correlation windows.
    signal correlation : signed(CORRELATION_WIDTH-1 downto 0) := (others => '0');
    signal energy : unsigned(CORRELATION_WIDTH-1 downto 0) := (others => '0');

    type unsigned_hist_5_t is array (0 to 4) of unsigned(CORRELATION_WIDTH-1 downto 0);

    signal high_threshold_c : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal low_threshold_c : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');

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
    envelope : entity work.adsb_envelope
        generic map (
            IQ_WIDTH        => IQ_WIDTH,
            MAGNITUDE_WIDTH => MAGNITUDE_WIDTH
        )
        port map (
            clk      => clk,
            ce_i     => ce_i,
            i_i      => i_i,
            q_i      => q_i,
            mag_sq_o => env_mag_sq,
            i_o      => env_i,
            q_o      => env_q
        );

    ce_c <= ce_i;
    high_threshold_o <= high_threshold_c;
    low_threshold_o <= low_threshold_c;
    i_o <= i_c;
    q_o <= q_c;
    mag_sq_o <= mag_sq_c;

    trigger_process : process(clk)
        variable sum_energy : unsigned(CORRELATION_WIDTH-1 downto 0);

        variable tmp_sym : symbol_energy_t;
        variable idx_sym : integer;

        constant THRESHOLD_SCALE : unsigned(CORRELATION_WIDTH-1 downto 0) := to_unsigned(1000000000, CORRELATION_WIDTH);
    begin
        if rising_edge(clk) then
            if ce_c = '1' then
                -- Append most recently arrived sample onto the end of the shift register.
                shift_reg(BUFFER_LENGTH-1) <= env_mag_sq;
                i_reg(PIPELINE_DELAY-1) <= env_i;
                q_reg(PIPELINE_DELAY-1) <= env_q;
                for i in 0 to BUFFER_LENGTH-2 loop
                    shift_reg(i) <= shift_reg(i+1);
                end loop;
                for i in 0 to PIPELINE_DELAY-2 loop
                    i_reg(i) <= i_reg(i+1);
                    q_reg(i) <= q_reg(i+1);
                end loop;

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
    end process trigger_process;

    detect_process : process(clk)
        variable all_thresholds_ok : boolean := false;
        variable threshold : unsigned(energy'length-1 downto 0);
        variable local_detect : boolean := false;
        variable energy_history : unsigned_hist_5_t;
        variable max_magnitude : unsigned(MAGNITUDE_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if ce_c = '1' then
                threshold := resize((energy * to_unsigned(3, energy'length+2)) srl 4, energy'length);
                all_thresholds_ok := true;
                for i in PREAMBLE_POSITION'range loop
                    if resize(sym_energy(i), energy'length) <= threshold then
                        all_thresholds_ok := false;
                    end if;
                end loop;

                if all_thresholds_ok then
                    local_detect := true;
                else
                    local_detect := false;
                end if;

                energy_history(4) := energy_history(3);
                energy_history(3) := energy_history(2);
                energy_history(2) := energy_history(1);
                energy_history(1) := energy_history(0);
                if local_detect then
                    energy_history(0) := energy;
                else
                    energy_history(0) := (others => '0');
                end if;

                if energy_history(2) > 0 then
                    if (energy_history(2) > energy_history(0)) and
                       (energy_history(2) > energy_history(1)) and
                       (energy_history(2) > energy_history(3)) and
                       (energy_history(2) > energy_history(4)) then
                        detect_o <= '1';
                        max_magnitude := max_over_preamble(shift_reg);
                        high_threshold_c <= max_magnitude srl 1;
                        low_threshold_c <= max_magnitude srl 3;
                    else
                        detect_o <= '0';
                    end if;
                else
                    detect_o <= '0';
                end if;
            end if;
        end if;
    end process detect_process;

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
