library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity preamble_detector is
    generic (
        SAMPLES_PER_SYMBOL     : integer;
        PREAMBLE_BUFFER_LENGTH : integer
    );
    port (
        clk : in std_logic;
        ce_i : in std_logic; -- Clock enable.
        i_i : in iq_t;
        q_i : in iq_t;

        i_o : out iq_t;
        q_o : out iq_t;
        mag_sq_o : out mag_sq_t;
        detect_o : out std_logic;
        high_threshold_o : out mag_sq_t;
        low_threshold_o : out mag_sq_t
    );
end preamble_detector;

architecture rtl of preamble_detector is
    -- Envelope outputs (inputs to the windower.)
    -- The envelope detector outputs magnitude squared from IQ.
    signal env_i        : iq_t := (others => '0');
    signal env_q        : iq_t := (others => '0');
    signal env_mag_sq   : mag_sq_t := (others => '0');

    -- Windower outputs (inputs to the peak detector.)
    signal win_i              : iq_t := (others => '0');
    signal win_q              : iq_t := (others => '0');
    signal win_mag_sq         : mag_sq_t := (others => '0');
    signal win_avg_carrier    : mag_sq_t := (others => '0');
    signal win_avg_noise      : mag_sq_t := (others => '0');
    signal win_inside_energy  : win_energy_t := (others => '0');
    signal win_outside_energy : win_energy_t := (others => '0');
    signal win_thres_ok       : std_logic := '0';

    -- Peak detector outputs (final outputs from the cascade.)
    signal pkd_i           : iq_t := (others => '0');
    signal pkd_q           : iq_t := (others => '0');
    signal pkd_mag_sq      : mag_sq_t := (others => '0');
    signal pkd_avg_carrier : mag_sq_t := (others => '0');
    signal pkd_avg_noise   : mag_sq_t := (others => '0');
    signal pkd_detect      : std_logic := '0';

    -- Output registers.
    signal i_r              : iq_t := (others => '0');
    signal q_r              : iq_t := (others => '0');
    signal mag_sq_r         : mag_sq_t := (others => '0');
    signal detect_r         : std_logic := '0';
    signal high_threshold_r : mag_sq_t := (others => '0');
    signal low_threshold_r  : mag_sq_t := (others => '0');

begin
    -- Magnitude-squared envelope detector.
    u_envelope_detector : entity work.adsb_envelope
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
            SAMPLES_PER_SYMBOL     => SAMPLES_PER_SYMBOL,
            PREAMBLE_BUFFER_LENGTH => PREAMBLE_BUFFER_LENGTH
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
            avg_carrier_o        => win_avg_carrier,
            avg_noise_o          => win_avg_noise
        );

    -- Peak detector.
    u_peak_detector : entity work.adsb_preamble_peak
        generic map (
            SAMPLES_PER_SYMBOL => SAMPLES_PER_SYMBOL
        )
        port map (
            clk                  => clk,
            ce_i                 => ce_i,
            i_i                  => win_i,
            q_i                  => win_q,
            mag_sq_i             => win_mag_sq,
            avg_carrier_i        => win_avg_carrier,
            avg_noise_i          => win_avg_noise,
            win_inside_energy_i  => win_inside_energy,
            win_outside_energy_i => win_outside_energy,
            all_thresholds_ok_i  => win_thres_ok,

            i_o                  => pkd_i,
            q_o                  => pkd_q,
            mag_sq_o             => pkd_mag_sq,
            avg_carrier_o        => pkd_avg_carrier,
            avg_noise_o          => pkd_avg_noise,
            detect_o             => pkd_detect
        );

    -- Drive outputs with registers.
    i_o              <= i_r;
    q_o              <= q_r;
    mag_sq_o         <= mag_sq_r;
    detect_o         <= detect_r;
    high_threshold_o <= high_threshold_r;
    low_threshold_o  <= low_threshold_r;

    -- Set up high and low hysteresis thresholds for the Schmitt trigger.
    schmitt_trigger_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_i = '1' then

                -- Pass through signals to the next stage, which is the Schmitt trigger.
                i_r      <= pkd_i;
                q_r      <= pkd_q;
                mag_sq_r <= pkd_mag_sq;
                detect_r <= pkd_detect;

                -- Latch the hysteresis thresholds when a preamble is detected.
                if pkd_detect = '1' then
                    -- High hysteresis threshold is half of the maximum of the envelope.
                    high_threshold_r <= resize(pkd_avg_carrier + pkd_avg_noise srl 1, high_threshold_r'length);

                    -- Low hysteresis threshold is one eighth of the maximum of the envelope.
                    -- TODO check this.
                    low_threshold_r <= resize((pkd_avg_carrier + to_unsigned(7, low_threshold_r'length+4) * pkd_avg_noise) srl 3, low_threshold_r'length);
                end if;
            end if;
        end if;
    end process schmitt_trigger_process;
end rtl;
