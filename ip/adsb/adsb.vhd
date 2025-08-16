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
        input_i : in signed(IQ_WIDTH-1 downto 0);
        input_q : in signed(IQ_WIDTH-1 downto 0)
    );
end adsb;

architecture Behavioral of adsb is
    component preamble_detector is
        port (
            input_i : in signed(11 downto 0);
            input_q : in signed(11 downto 0);
            high_threshold : out unsigned(24 downto 0);
            low_threshold : out unsigned(24 downto 0);
            detect : out std_logic;
            clk : in std_logic
       );
    end component;

    component schmitt_trigger is
        port (
            magnitude_sq : in unsigned(24 downto 0);
            high_threshold : in unsigned(24 downto 0);
            low_threshold : in unsigned(24 downto 0);
            output : out std_logic;
            ce : in std_logic := '0'; -- Clock enable.
            clk : in std_logic
        );
    end component;

    signal detect : std_logic := '0';
    signal triggered : std_logic := '0';
    signal magnitude_sq : unsigned(24 downto 0) := (others => '0');
    signal high_threshold : unsigned(24 downto 0) := (others => '0');
    signal low_threshold : unsigned(24 downto 0) := (others => '0');
begin

    detector: preamble_detector port map (
        input_i => input_i,
        input_q => input_q,
        detect => detect,
        high_threshold => high_threshold,
        low_threshold => low_threshold,
        clk => clk
    );
    
    trigger: schmitt_trigger port map (
        magnitude_sq => magnitude_sq,
        output => triggered,
        high_threshold => high_threshold,
        low_threshold => low_threshold,
        ce => '1',
        clk => clk
    );

    main_process : process(clk)
    begin
        if rising_edge(clk) then
        end if;
    end process main_process;

end Behavioral;

