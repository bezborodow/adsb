library ieee;
use ieee.std_logic_1164.all;

use ieee.numeric_std.all;
use ieee.math_real.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use work.correlator_pkg.all;

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

begin
    main_process : process(clk)
    begin
        if rising_edge(clk) then
        end if;
    end process main_process;

end Behavioral;

