library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_preamble_peak is
    generic (
        IQ_WIDTH        : integer := ADSB_DEFAULT_IQ_WIDTH;
        MAGNITUDE_WIDTH : integer := ADSB_DEFAULT_IQ_WIDTH * 2 + 1;
        SAMPLES_PER_SYMBOL : integer := ADSB_DEFAULT_SAMPLES_PER_SYMBOL
    );
    port (
        clk : in std_logic;
        ce_i : in std_logic; -- Clock enable.
        i_i : in signed(IQ_WIDTH-1 downto 0);
        q_i : in signed(IQ_WIDTH-1 downto 0);
        mag_sq_i : in unsigned(MAGNITUDE_WIDTH-1 downto 0);
        max_mag_sq_i : in unsigned(MAGNITUDE_WIDTH-1 downto 0);
        win_inside_energy_i : in unsigned(MAGNITUDE_WIDTH+integer(ceil(log2(real(16 * SAMPLES_PER_SYMBOL))))-1 downto 0); -- TODO Move constant to package?
        win_outside_energy_i : in unsigned(MAGNITUDE_WIDTH+integer(ceil(log2(real(16 * SAMPLES_PER_SYMBOL))))-1 downto 0);
        all_thresholds_ok_i : in std_logic;

        i_o : out signed(IQ_WIDTH-1 downto 0);
        q_o : out signed(IQ_WIDTH-1 downto 0);
        mag_sq_o : out unsigned(MAGNITUDE_WIDTH-1 downto 0);
        max_mag_sq_o : out unsigned(MAGNITUDE_WIDTH-1 downto 0);
        detect_o : out std_logic
    );
end adsb_preamble_peak;

architecture rtl of adsb_preamble_peak is

    signal high_threshold_r : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal low_threshold_r : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');

    constant RECORD_ARRAY_LENGTH : positive := 5;

    type windowed_sample_record_t is record
        i             : signed(IQ_WIDTH-1 downto 0);
        q             : signed(IQ_WIDTH-1 downto 0);
        mag_sq        : unsigned(MAGNITUDE_WIDTH-1 downto 0);
        max_mag_sq    : unsigned(MAGNITUDE_WIDTH-1 downto 0);
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
begin

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
end rtl;
