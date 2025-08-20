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
        SAMPLES_PER_SYMBOL : integer := 10; -- 40e6*500e-9
        IQ_WIDTH : integer := 12
    );
    port (
        clk : in std_logic;
        i_i : in signed(IQ_WIDTH-1 downto 0);
        q_i : in signed(IQ_WIDTH-1 downto 0)
    );
end adsb;

architecture Behavioral of adsb is
    constant MAGNITUDE_WIDTH : integer := IQ_WIDTH * 2 + 1;

    signal detect : std_logic := '0';
    signal gate : std_logic := '0';
    signal magnitude_sq : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal high_threshold : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal low_threshold : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');

    signal detector_i : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal detector_q : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal detector_i_z1 : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal detector_q_z1 : signed(IQ_WIDTH-1 downto 0) := (others => '0');

    signal freq_est_en : std_logic := '0';
    signal freq_est_vld : std_logic := '0';
    signal freq_est_rdy : std_logic := '0';
 
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
        mag_sq_o => magnitude_sq
    );
    
    trigger: entity work.schmitt_trigger
    generic map (
        SIGNAL_WIDTH => MAGNITUDE_WIDTH
    )
    port map (
        clk => clk,
        ce_i => '1',
        schmitt_i => magnitude_sq,
        high_threshold_i => high_threshold,
        low_threshold_i => low_threshold,
        schmitt_o => gate
    );

    freq_est: entity work.freq_est port map (
        clk => clk,
        gate_i => gate,
        en_i => freq_est_en,
        i_i => detector_i_z1,
        q_i => detector_q_z1,
        rdy_i => freq_est_rdy,
        vld_o => freq_est_vld
    );

    main_process : process(clk)
    begin
        if rising_edge(clk) then
            detector_i_z1 <= detector_i;
            detector_q_z1 <= detector_q;
        end if;
    end process main_process;

end Behavioral;

