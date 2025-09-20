library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_preamble_peak is
    generic (
        IQ_WIDTH        : integer := ADSB_DEFAULT_IQ_WIDTH;
        MAGNITUDE_WIDTH : integer := ADSB_DEFAULT_IQ_WIDTH * 2 + 1
    );
    port (
        clk : in std_logic;
        ce_i : in std_logic; -- Clock enable.
        i_i : in signed(IQ_WIDTH-1 downto 0);
        q_i : in signed(IQ_WIDTH-1 downto 0);
        mag_sq_i : in unsigned(MAGNITUDE_WIDTH-1 downto 0);
        max_mag_sq_i : in unsigned(MAGNITUDE_WIDTH-1 downto 0);
        win_inside_energy_i : in unsigned(MAGNITUDE_WIDTH-1 downto 0);
        win_outside_energy_i : in unsigned(MAGNITUDE_WIDTH-1 downto 0);

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
        win_ei        : unsigned(MAGNITUDE_WIDTH-1 downto 0);
        win_eo        : unsigned(MAGNITUDE_WIDTH-1 downto 0);
        win_et        : unsigned(MAGNITUDE_WIDTH downto 0);
        thresholds_ok : std_logic;
        max_mag_sq    : unsigned(MAGNITUDE_WIDTH-1 downto 0);
    end record;
    
    type windowed_sample_record_array_t is array (natural range <>) of windowed_sample_record_t;

    -- type unsigned_hist_5_t is array (0 to 4) of unsigned(CORRELATION_WIDTH-1 downto 0);
begin

    history_buffer_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                -- TODO Register inputs into buffer.
            end if;
        end if;
    end process history_buffer_process;
end rtl;
