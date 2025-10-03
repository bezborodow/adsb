library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb is
    generic (
        SAMPLES_PER_SYMBOL     : integer;
        PREAMBLE_BUFFER_LENGTH : integer;
        ACCUMULATION_LENGTH    : integer
    );
    port (
        clk : in std_logic;
        d_vld_i : in std_logic;
        i_i : in iq_t;
        q_i : in iq_t;
        vld_o : out std_logic;
        detect_o : out std_logic;
        rdy_i : in std_logic;
        w56_o : out std_logic;
        data_o : out std_logic_vector(111 downto 0);
        est_re_o : out signed(31 downto 0);
        est_im_o : out signed(31 downto 0)
    );
end adsb;

architecture rtl of adsb is
    -- Internal signals and registers.
    signal rdy_r : std_logic := '0';
    signal vld_r : std_logic := '0';
    signal d_vld_r : std_logic := '0';

    -- Preamble detector signals.
    signal detector_detect : std_logic := '0';
    signal detector_high_threshold : mag_sq_t := (others => '0');
    signal detector_low_threshold : mag_sq_t := (others => '0');
    signal detector_mag_sq : mag_sq_t := (others => '0');
    signal detector_i, detector_q : iq_t := (others => '0');

    -- Schmitt trigger signals.
    signal trigger_detect : std_logic := '0';
    signal trigger_i, trigger_q : iq_t := (others => '0');
    signal trigger_schmitt : std_logic := '0';

    -- Frequency estimator signals.
    signal estimator_en : std_logic := '0';
    signal estimator_vld : std_logic := '0';
    signal estimator_rdy : std_logic := '0';
    signal estimator_re : signed(31 downto 0) := (others => '0');
    signal estimator_im : signed(31 downto 0) := (others => '0');

    -- Pulse-position modulation (PPM) demodulator signals.
    signal demod_malformed : std_logic := '0';
    signal demod_vld : std_logic := '0';
    signal demod_rdy : std_logic := '0';
    signal demod_w56 : std_logic := '0';
    signal demod_data : std_logic_vector(111 downto 0) := (others => '0');

begin
    u_detector : entity work.preamble_detector
        generic map (
            SAMPLES_PER_SYMBOL     => SAMPLES_PER_SYMBOL,
            PREAMBLE_BUFFER_LENGTH => PREAMBLE_BUFFER_LENGTH
        )
        port map (
            clk => clk,
            ce_i => d_vld_r,
            i_i => i_i,
            q_i => q_i,

            detect_o => detector_detect,
            high_threshold_o => detector_high_threshold,
            low_threshold_o => detector_low_threshold,
            i_o => detector_i,
            q_o => detector_q,
            mag_sq_o => detector_mag_sq
        );

    -- Schmitt trigger.
    -- Used for demodulating the ADS-B signal and gating the frequency estimator.
    -- Hysteresis thresholds are adjusted based on the magnitude of the preamble.
    u_trigger : entity work.schmitt_trigger
        generic map (
            SIGNAL_WIDTH => IQ_MAG_SQ_WIDTH
        )
        port map (
            clk => clk,
            ce_i => d_vld_r,
            i_i => detector_i,
            q_i => detector_q,
            mag_sq_i => detector_mag_sq,
            detect_i => detector_detect,
            high_threshold_i => detector_high_threshold,
            low_threshold_i => detector_low_threshold,

            i_o => trigger_i,
            q_o => trigger_q,
            detect_o => trigger_detect,
            schmitt_o => trigger_schmitt
        );

    -- PPM demodulator.
    u_demodulator : entity work.ppm_demod
        generic map (
            SAMPLES_PER_SYMBOL => SAMPLES_PER_SYMBOL
        )
        port map (
            clk => clk,
            ce_i => d_vld_r,
            rdy_i => demod_rdy,
            schmitt_i => trigger_schmitt,
            detect_i => trigger_detect,

            vld_o => demod_vld,
            data_o => demod_data,
            w56_o => demod_w56,
            malformed_o => demod_malformed
        );

    -- Frequency estimator.
    u_freq_est : entity work.freq_est
        generic map (
            ACCUMULATION_LENGTH => ACCUMULATION_LENGTH
        )
        port map (
            clk => clk,
            ce_i => d_vld_r,
            i_i => trigger_i,
            q_i => trigger_q,
            gate_i => trigger_schmitt,
            start_i => trigger_detect,
            stop_i => demod_vld,

            rdy_i => estimator_rdy,
            vld_o => estimator_vld,
            est_re_o => estimator_re,
            est_im_o => estimator_im
        );

    d_vld_r <= d_vld_i;
    vld_o <= vld_r;
    detect_o <= detector_detect;
    rdy_r <= rdy_i;
    vld_r <= demod_vld and estimator_vld;
    demod_rdy <= vld_r and rdy_r;
    estimator_rdy <= vld_r and rdy_r;
    est_re_o <= estimator_re;
    est_im_o <= estimator_im;
    data_o <= demod_data;
    w56_o <= demod_w56;
end rtl;
