library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_preamble_peak is
    generic (
        SAMPLES_PER_SYMBOL : positive
    );
    port (
        clk : in std_logic;
        ce_i : in std_logic; -- Clock enable.
        i_i : in signed(IQ_WIDTH-1 downto 0);
        q_i : in signed(IQ_WIDTH-1 downto 0);
        mag_sq_i : in mag_sq_t;
        max_mag_sq_i : in mag_sq_t;
        win_inside_energy_i : in unsigned(IQ_MAG_SQ_WIDTH+integer(ceil(log2(real(16 * SAMPLES_PER_SYMBOL))))-1 downto 0); -- TODO Move constant to package?
        win_outside_energy_i : in unsigned(IQ_MAG_SQ_WIDTH+integer(ceil(log2(real(16 * SAMPLES_PER_SYMBOL))))-1 downto 0);
        all_thresholds_ok_i : in std_logic;

        i_o : out signed(IQ_WIDTH-1 downto 0);
        q_o : out signed(IQ_WIDTH-1 downto 0);
        mag_sq_o : out mag_sq_t;
        max_mag_sq_o : out mag_sq_t;
        detect_o : out std_logic
    );
end adsb_preamble_peak;

architecture rtl of adsb_preamble_peak is

    constant RECORD_ARRAY_LENGTH : positive := 5;
    constant CENTRE_RECORD : positive := RECORD_ARRAY_LENGTH / 2;

    -- Record buffer for samples that come from the windower with threshold and energy metadata.
    type windowed_sample_record_t is record
        i             : signed(IQ_WIDTH-1 downto 0);
        q             : signed(IQ_WIDTH-1 downto 0);
        mag_sq        : mag_sq_t;
        max_mag_sq    : mag_sq_t;
        win_ei        : unsigned(win_inside_energy_i'length-1 downto 0);
        win_eo        : unsigned(win_outside_energy_i'length-1 downto 0);
        thresholds_ok : std_logic;
    end record;
    type windowed_sample_record_array_t is array (natural range <>) of windowed_sample_record_t;
    signal history_a : windowed_sample_record_array_t(0 to RECORD_ARRAY_LENGTH-1) := (
        others => (
            i             => (others => '0'),
            q             => (others => '0'),
            mag_sq        => (others => '0'),
            max_mag_sq    => (others => '0'),
            win_ei        => (others => '0'),
            win_eo        => (others => '0'),
            thresholds_ok => '0'
        )
    );

    -- Peak detection signals.
    -- Array of products used in cross-multiplication and comparison.
    constant K_MAX : natural := RECORD_ARRAY_LENGTH - 2;
    subtype energy_product_t is unsigned(win_inside_energy_i'length*2-1 downto 0);
    type energy_product_array_t is array (0 to K_MAX) of energy_product_t;
    signal lhs_r, lhs_z1 : energy_product_array_t := (others => (others => '0'));
    signal rhs_r, rhs_z1 : energy_product_array_t := (others => (others => '0'));

    -- Is A greater than B?
    -- Centre record greater than its neighbours for each neighbour?
    signal agtb_r : std_logic_vector(0 to K_MAX) := (others => '0');

    -- Delay of threshold signal to keep things in sync.
    signal thres_ok_z1 : std_logic := '0';
    signal thres_ok_z2 : std_logic := '0';
    signal thres_ok_z3 : std_logic := '0';

    -- Registered signals for outputs.
    signal i_r, i_z3 : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal q_r, q_z3 : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal mag_sq_r, mag_sq_z3 : mag_sq_t := (others => '0');
    signal max_mag_sq_r, max_mag_sq_z3 : mag_sq_t := (others => '0');
    signal detect_r : std_logic := '0';

    -- Check that all bits in a standard logic vector are '1'.
    function all_bits_high(v : std_logic_vector) return boolean is
    begin
        for i in v'range loop
            if v(i) /= '1' then
                return false;
            end if;
        end loop;

        return true;
    end function;

begin
    -- Drive outputs from registered signals.
    i_o          <= i_r;
    q_o          <= q_r;
    mag_sq_o     <= mag_sq_r;
    max_mag_sq_o <= max_mag_sq_r;
    detect_o     <= detect_r;

    -- Buffer windowed sample records into a history array.
    history_buffer_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                -- Register inputs into buffer.
                for i in RECORD_ARRAY_LENGTH-1 downto 1 loop
                    history_a(i) <= history_a(i-1);
                end loop;
                history_a(0).i             <= i_i;
                history_a(0).q             <= q_i;
                history_a(0).mag_sq        <= mag_sq_i;
                history_a(0).max_mag_sq    <= max_mag_sq_i;
                history_a(0).win_ei        <= win_inside_energy_i;
                history_a(0).win_eo        <= win_outside_energy_i;
                history_a(0).thresholds_ok <= all_thresholds_ok_i;
            end if;
        end if;
    end process history_buffer_process;

    peak_detector_process : process(clk)
        variable centre_v : windowed_sample_record_t;
        variable local_maximum_v : std_logic := '0';
        variable eai_v, ebi_v : unsigned(win_inside_energy_i'length-1 downto 0) := (others => '0');
        variable eao_v, ebo_v : unsigned(win_outside_energy_i'length-1 downto 0) := (others => '0');
        variable k : integer range 0 to 3 := 0;
    begin
        if rising_edge(clk) then
            if ce_i = '1' then

                centre_v := history_a(CENTRE_RECORD);

                -- Compare centre record against neighbours to find a local peak.
                local_maximum_v := '1'; -- Default to '1', then turn off upon failure to meet conditions.
                k := 0;

                thres_ok_z1 <= centre_v.thresholds_ok;
                thres_ok_z2 <= thres_ok_z1;
                thres_ok_z3 <= thres_ok_z2;
                for i in history_a'range loop

                    -- Skip centre record.
                    if i /= CENTRE_RECORD then
                        -- If the energy ratio of the centre record is greater than its
                        -- neighbours, then it is a local maxima (peak), but also need
                        -- to check that all thresholds of the four high symbol energies
                        -- are okay.
                        --
                        -- The formula is:
                        --
                        --     E_ai / E_ao > E_bi / E_bo;
                        --
                        -- Using cross-multiplication:
                        --
                        --     E_ai * E_bo > E_bi * E_ao
                        --
                        -- Where 'E' is energy, subscript 'a' is centre, 'b' is neighbour,
                        -- subscript 'i' is inside, and 'o' is outside.
                        --
                        -- This needs to be registered for the DSP in stages.
                        eai_v := centre_v.win_ei;
                        eao_v := centre_v.win_eo;
                        ebi_v := history_a(i).win_ei;
                        ebo_v := history_a(i).win_eo;

                        -- DSP multiplication, left-hand side (LHS) and right-hand side (RHS.)
                        lhs_r(k) <= eai_v * ebo_v;
                        rhs_r(k) <= ebi_v * eao_v;

                        -- Register between multiply and comparison for DSP.
                        lhs_z1(k) <= lhs_r(k);
                        rhs_z1(k) <= rhs_r(k);

                        -- Comparison.
                        if lhs_z1(k) > rhs_z1(k) then
                            agtb_r(k) <= '1'; -- A is greater than B (AGTB.)
                        else
                            agtb_r(k) <= '0';
                        end if;

                        -- Check next kth neighbour.
                        if k < K_MAX then
                            k := k + 1;
                        end if;
                    end if;
                end loop;

                -- Register the detect strobe if all conditions are met.
                -- If the record is greater than its neighbours and thresholds are okay.
                -- There is two cycles of delay (z2) prior to this operation that
                -- needs to be accounted for.
                if all_bits_high(agtb_r) and (thres_ok_z3 = '1') then
                    detect_r <= '1';
                else
                    detect_r <= '0';
                end if;
            end if;
        end if;
    end process peak_detector_process;

    -- Pass-through signals delayed against the pipeline delay.
    delay_process : process(clk)
        constant DELAY_OFFSET : integer := 2;
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                i_z3          <= history_a(CENTRE_RECORD + DELAY_OFFSET).i;
                q_z3          <= history_a(CENTRE_RECORD + DELAY_OFFSET).q;
                mag_sq_z3     <= history_a(CENTRE_RECORD + DELAY_OFFSET).mag_sq;
                max_mag_sq_z3 <= history_a(CENTRE_RECORD + DELAY_OFFSET).max_mag_sq;

                -- The delay is actually more than the buffer, so need an additional register.
                i_r          <= i_z3;
                q_r          <= q_z3;
                mag_sq_r     <= mag_sq_z3;
                max_mag_sq_r <= max_mag_sq_z3;
            end if;
        end if;
    end process delay_process;
end rtl;
