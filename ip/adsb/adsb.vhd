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
    signal triggered : std_logic := '0';
    signal magnitude_sq : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal high_threshold : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
    signal low_threshold : unsigned(MAGNITUDE_WIDTH-1 downto 0) := (others => '0');
begin

    detector: entity work.preamble_detector port map (
        i_i => i_i,
        q_i => q_i,
        detect_o => detect,
        high_threshold_o => high_threshold,
        low_threshold_o => low_threshold,
        clk => clk
    );
    
    trigger: entity work.schmitt_trigger port map (
        magnitude_sq => magnitude_sq,
        output => triggered,
        high_threshold_i => high_threshold,
        low_threshold_i => low_threshold,
        ce => '1',
        clk => clk
    );

    main_process : process(clk)
    begin
        if rising_edge(clk) then
        end if;
    end process main_process;

end Behavioral;

