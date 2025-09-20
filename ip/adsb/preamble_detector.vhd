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
        BUFFER_LENGTH         : integer := ADSB_DEFAULT_PREAMBLE_BUFFER_LENGTH; -- TODO Not needed.
        PREAMBLE_POSITION1     : integer := 20; -- TODO Not needed.
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
    -- Accumulator width for for entire preamble buffer.
    constant BUFFER_ACCUMULATOR_WIDTH : positive := MAGNITUDE_WIDTH + integer(ceil(log2(real(BUFFER_LENGTH))));

    -- Envelope outputs (inputs to the windower.)
    signal env_i        : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal env_q        : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal env_mag_sq   : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');

    -- Windower outputs (inputs to the peak detector.)
    signal win_i              : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal win_q              : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal win_mag_sq         : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal win_inside_energy  : unsigned(BUFFER_ACCUMULATOR_WIDTH-1 downto 0) := (others => '0');
    signal win_outside_energy : unsigned(BUFFER_ACCUMULATOR_WIDTH-1 downto 0) := (others => '0');
    signal win_max_mag_sq     : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal win_thres_ok       : std_logic;

    -- Peak outputs (final outputs from the cascade.)
    signal pk_i          : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal pk_q          : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal pk_mag_sq     : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal pk_max_mag_sq : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal pk_detect     : std_logic := '0';

    -- TODO Schmitt trigger thresholds.
    signal high_threshold_r : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal low_threshold_r : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');

begin
    -- Magnitude-squared envelope detector.
    u_envelope_detector : entity work.adsb_envelope
        generic map (
            IQ_WIDTH        => IQ_WIDTH,
            MAGNITUDE_WIDTH => MAGNITUDE_WIDTH
        )
        port map (
            clk      => clk,
            ce_i     => ce_i,
            i_i      => i_i,
            q_i      => q_i,

            i_o      => env_i,
            q_o      => env_q,
            mag_sq_o => env_mag_sq
        );

    -- Preamble energy sliding windower.
    -- Used instead of a correlator; not the same thing, but similar purpose!
    u_windower : entity work.adsb_preamble_window
        generic map (
            SAMPLES_PER_SYMBOL => SAMPLES_PER_SYMBOL,
            IQ_WIDTH           => IQ_WIDTH,
            MAGNITUDE_WIDTH    => MAGNITUDE_WIDTH
        )
        port map (
            clk                  => clk,
            ce_i                 => ce_i,
            i_i                  => env_i,
            q_i                  => env_q,
            mag_sq_i             => env_mag_sq,

            i_o                  => win_i,
            q_o                  => win_q,
            mag_sq_o             => win_mag_sq,
            win_inside_energy_o  => win_inside_energy,
            win_outside_energy_o => win_outside_energy,
            all_thresholds_ok_o  => win_thres_ok,
            max_mag_sq_o         => win_max_mag_sq
        );

    -- Peak detector.
    u_peak : entity work.adsb_preamble_peak
        generic map (
            SAMPLES_PER_SYMBOL => SAMPLES_PER_SYMBOL,
            IQ_WIDTH           => IQ_WIDTH,
            MAGNITUDE_WIDTH    => MAGNITUDE_WIDTH
        )
        port map (
            clk                  => clk,
            ce_i                 => ce_i,
            i_i                  => win_i,
            q_i                  => win_q,
            mag_sq_i             => win_mag_sq,
            max_mag_sq_i         => win_max_mag_sq,
            win_inside_energy_i  => win_inside_energy,
            win_outside_energy_i => win_outside_energy,
            all_thresholds_ok_i  => win_thres_ok,

            i_o                  => pk_i,
            q_o                  => pk_q,
            mag_sq_o             => pk_mag_sq,
            max_mag_sq_o         => pk_max_mag_sq,
            detect_o             => pk_detect
        );
end rtl;
