library ieee;
use ieee.std_logic_1164.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use ieee.numeric_std.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use work.correlator_pkg.all;

entity preamble_detector is
    generic (
        SAMPLES_PER_SYMBOL : integer := 20; -- 40e6*500e-9
        BUFFER_SYMBOL_LENGTH : integer := 16; -- 16 Symbols.
        IQ_WIDTH : integer := 12
    );
    port (
        input_i : in signed(IQ_WIDTH-1 downto 0);
        input_q : in signed(IQ_WIDTH-1 downto 0);
        detect : out std_logic;
        clk : in std_logic
    );
end preamble_detector;

architecture Behavioral of preamble_detector is
    constant BUFFER_LENGTH : integer := SAMPLES_PER_SYMBOL * BUFFER_SYMBOL_LENGTH;

    type iq_buffer_t is array (natural range <>) of unsigned(24 downto 0);
    signal shift_reg : iq_buffer_t(0 to BUFFER_LENGTH-1);

begin
    trigger_process : process(clk)
        variable input_i_sq : signed(IQ_WIDTH*2-1 downto 0);
        variable input_q_sq : signed(IQ_WIDTH*2-1 downto 0);
        variable magnitude_sq : unsigned(IQ_WIDTH*2 downto 0);
    begin
        if (rising_edge(clk)) then
            input_i_sq := input_i * input_i;
            input_q_sq := input_q * input_q;
            magnitude_sq := resize(unsigned(input_i_sq), magnitude_sq'length) + resize(unsigned(input_q_sq), magnitude_sq'length);

	        shift_reg(0) <= magnitude_sq;
            for i in 1 to BUFFER_LENGTH-1 loop
                shift_reg(i) <= shift_reg(i-1);
            end loop;
        end if;
    end process trigger_process;


    --C <= C + resize(x, C'length) * resize(p(sample_idx), C'length);
end Behavioral;

