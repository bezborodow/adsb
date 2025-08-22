library ieee;
use ieee.std_logic_1164.all;

use ieee.numeric_std.all;
use ieee.math_real.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity adsb is
    generic (
        SAMPLES_PER_SYMBOL : integer := 10;
        IQ_WIDTH : integer := 12
    );
    port (
        clk : in std_logic;
        i_i : in signed(IQ_WIDTH-1 downto 0);
        q_i : in signed(IQ_WIDTH-1 downto 0);
        vld_o : out std_logic;
        rdy_i : in std_logic;
        w56_o : out std_logic;
        data_o : out std_logic_vector(111 downto 0)
    );
end adsb;

architecture Behavioral of adsb is
    constant MAGNITUDE_WIDTH : integer := IQ_WIDTH * 2 + 1;

    -- Internal signals and registers.
    signal rdy_r : std_logic := '0';
    signal vld_r : std_logic := '0';

    -- Preamble detector signals.
    signal detect : std_logic := '0';
    signal high_threshold : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal low_threshold : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal detector_mag_sq : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal detector_i : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal detector_q : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal detector_i_z1 : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal detector_q_z1 : signed(IQ_WIDTH-1 downto 0) := (others => '0');

    -- Schmitt trigger signals.
    signal trigger_envelope : std_logic := '0';

    -- Frequency estimator signals.
    signal estimator_en : std_logic := '0';
    signal estimator_vld : std_logic := '0';
    signal estimator_rdy : std_logic := '0';

    -- Pulse-position modulation (PPM) demodulator signals.
    signal demod_malformed : std_logic := '0';
    signal demod_vld : std_logic := '0';
    signal demod_rdy : std_logic := '0';
    signal demod_w56 : std_logic := '0';
    signal demod_data : std_logic_vector(111 downto 0) := (others => '0');
 
begin
    detector: entity work.preamble_detector port map (
        clk => clk,
        i_i => i_i,
        q_i => q_i,
        detect_o => detect,
        high_threshold_o => high_threshold,
        low_threshold_o => low_threshold,

        i_o => detector_i,
        q_o => detector_q,
        mag_sq_o => detector_mag_sq
    );
    
    trigger: entity work.schmitt_trigger
    generic map (
        SIGNAL_WIDTH => MAGNITUDE_WIDTH
    )
    port map (
        clk => clk,
        ce_i => '1',
        schmitt_i => detector_mag_sq,
        high_threshold_i => high_threshold,
        low_threshold_i => low_threshold,
        schmitt_o => trigger_envelope
    );

    -- PPM demodulator.
    demod: entity work.ppm_demod port map (
        clk => clk,
        ce_i => '1',
        rdy_i => demod_rdy, -- TODO
        envelope_i => trigger_envelope,
        detect_i => detect,
        vld_o => demod_vld,
        data_o => demod_data,
        w56_o => demod_w56,
        malformed_o => demod_malformed
    );

    -- Frequency estimator.
    freq_est: entity work.freq_est port map (
        clk => clk,
        gate_i => trigger_envelope,
        start_i => detect,
        --stop_i => malformed or demod_vld,
        stop_i => '0', -- TODO
        i_i => detector_i_z1,
        q_i => detector_q_z1,
        rdy_i => estimator_rdy,
        vld_o => estimator_vld
    );

    main_process : process(clk)
    begin
        if rising_edge(clk) then
            detector_i_z1 <= detector_i;
            detector_q_z1 <= detector_q;
        end if;
    end process main_process;

    vld_o <= vld_r;
    rdy_r <= rdy_i;
    rdyvld_handshake_process : process(clk)
    begin
        if rising_edge(clk) then
            if demod_vld = '1' and estimator_vld = '1' then
                vld_r <= '1';
            end if;

            if vld_r = '1' and rdy_r ='1' then
                demod_rdy <= '1';
                estimator_rdy <= '1';
                vld_r <= '0';
            end if;
        end if;
    end process rdyvld_handshake_process;

end Behavioral;

