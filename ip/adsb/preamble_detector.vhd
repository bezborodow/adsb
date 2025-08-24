library ieee;
use ieee.std_logic_1164.all;

use ieee.numeric_std.all;
use ieee.math_real.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

--use work.correlator_pkg.all;
use work.adsb_pkg.all;

entity preamble_detector is
    generic (
        SAMPLES_PER_SYMBOL    : integer := DEFAULT_SAMPLES_PER_SYMBOL;
        BUFFER_SYMBOL_LENGTH  : integer := DEFAULT_BUFFER_SYMBOL_LENGTH;
        IQ_WIDTH              : integer := DEFAULT_IQ_WIDTH;
        MAGNITUDE_WIDTH       : integer := DEFAULT_IQ_WIDTH * 2 + 1
    );
    port (
        clk : in std_logic;
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

architecture Behavioral of preamble_detector is
    -- How many samples the IQ stream is delayed by compared to when the preamble is detected.
    constant PIPELINE_DELAY : integer := 5;

    constant BUFFER_LENGTH : integer := SAMPLES_PER_SYMBOL * BUFFER_SYMBOL_LENGTH;
    constant CORRELATION_WIDTH : integer := MAGNITUDE_WIDTH + integer(ceil(log2(real(BUFFER_LENGTH))));

    -- Where each pulse in the preamble starts.
    -- There are four pulses in the preamble of an ADS-B message.
    type int_array_t is array (natural range <>) of integer;
    constant PREAMBLE_POS : int_array_t := (0, 2, 7, 9);

    -- Energy in each pulse window.
    constant WINDOW_WIDTH : integer := (IQ_WIDTH*2) + integer(ceil(log2(real(SAMPLES_PER_SYMBOL))));
    type symbol_energy_t is array (0 to PREAMBLE_POS'length-1) of unsigned(WINDOW_WIDTH-1 downto 0);
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

    signal high_threshold_r : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal low_threshold_r : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');

    function max_over_preamble(sr : mag_sq_buffer_t) return unsigned is
        variable m       : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
        variable s       : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
        variable idx_sym : integer;
    begin
        for i in 0 to PREAMBLE_POS'length-1 loop
            for ii in 0 to SAMPLES_PER_SYMBOL-1 loop
                idx_sym := PREAMBLE_POS(i) * SAMPLES_PER_SYMBOL + ii;
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
    high_threshold_o <= high_threshold_r;
    low_threshold_o <= low_threshold_r;

    trigger_process : process(clk)
        variable input_i_sq : signed(IQ_WIDTH*2-1 downto 0);
        variable input_q_sq : signed(IQ_WIDTH*2-1 downto 0);
        variable magnitude_sq : unsigned(MAGNITUDE_WIDTH-1 downto 0);
        variable sum_energy : unsigned(CORRELATION_WIDTH-1 downto 0);

        variable tmp_sym : symbol_energy_t;
        variable idx_sym : integer;

        constant THRESHOLD_SCALE : unsigned(CORRELATION_WIDTH-1 downto 0) := to_unsigned(1000000000, CORRELATION_WIDTH);
    begin
        if rising_edge(clk) then
            input_i_sq := i_i * i_i;
            input_q_sq := q_i * q_i;
            magnitude_sq := resize(unsigned(input_i_sq), magnitude_sq'length) + resize(unsigned(input_q_sq), magnitude_sq'length);

            -- Append most recently arrived sample onto the end of the shift register.
	        shift_reg(BUFFER_LENGTH-1) <= magnitude_sq;
	        i_reg(PIPELINE_DELAY-1) <= i_i;
	        q_reg(PIPELINE_DELAY-1) <= q_i;
            for i in 0 to BUFFER_LENGTH-2 loop
                shift_reg(i) <= shift_reg(i+1);
            end loop;
            for i in 0 to PIPELINE_DELAY-2 loop
                i_reg(i) <= i_reg(i+1);
                q_reg(i) <= q_reg(i+1);
            end loop;

            -- zero local accumulators
            for j in 0 to PREAMBLE_POS'length-1 loop
                tmp_sym(j) := (others => '0');
            end loop;

            -- sum each symbol bin from the shift_reg. Assumes shift_reg(0) is most recent sample.
            for i in 0 to PREAMBLE_POS'length-1 loop
                for ii in 0 to SAMPLES_PER_SYMBOL-1 loop
                    idx_sym := PREAMBLE_POS(i)*SAMPLES_PER_SYMBOL + ii;
                    tmp_sym(i) := tmp_sym(i) + resize(shift_reg(idx_sym), tmp_sym(i)'length);
                end loop;
            end loop;

            -- write back to signals (or keep as variables)
            for j in 0 to PREAMBLE_POS'length-1 loop
                sym_energy(j) <= tmp_sym(j);
            end loop;

            sum_energy := (others => '0');
            for i in 0 to BUFFER_LENGTH-1 loop
                sum_energy := sum_energy + resize(shift_reg(BUFFER_LENGTH-i-1), sum_energy'length);
            end loop;
            energy <= sum_energy;
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
            threshold := resize((energy * to_unsigned(3, energy'length+2)) srl 4, energy'length);
            all_thresholds_ok := true;
            for i in PREAMBLE_POS'range loop
                if resize(sym_energy(i), energy'length) <= threshold then
                    all_thresholds_ok := false;
                end if;
            end loop;

            --VHDL 1076-2008 only.
            --local_detect := true when all_thresholds_ok else false;
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
                    high_threshold_r <= max_magnitude srl 1;
                    low_threshold_r <= max_magnitude srl 3;
                else
                    detect_o <= '0';
                end if;
            else
                detect_o <= '0';
            end if;
        end if;
    end process detect_process;

    -- Passthrough signals delayed against the pipeline delay.
    -- These signals are useful for keeping everything synchronised, since
    -- preamble detection introduces delay.
    delay_process : process(clk)
    begin
        if rising_edge(clk) then
            i_o <= i_reg(0);
            q_o <= q_reg(0);
            mag_sq_o <= shift_reg(BUFFER_LENGTH - PIPELINE_DELAY);
        end if;
    end process delay_process;

end Behavioral;

