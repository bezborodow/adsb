library ieee;
use ieee.std_logic_1164.all;

use ieee.numeric_std.all;
use ieee.math_real.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use work.correlator_pkg.all;

entity preamble_detector is
    generic (
        SAMPLES_PER_SYMBOL : integer := 10; -- 40e6*500e-9
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
    constant CORRELATION_WIDTH : integer := (IQ_WIDTH*2) + integer(ceil(log2(real(BUFFER_LENGTH))));

    type iq_buffer_t is array (natural range <>) of unsigned(IQ_WIDTH*2 downto 0);
    signal shift_reg : iq_buffer_t(0 to BUFFER_LENGTH-1) := (others => (others => '0'));

    signal correlation : signed(CORRELATION_WIDTH-1 downto 0) := (others => '0');
    --signal correlation_sq : unsigned(2*CORRELATION_WIDTH-1 downto 0) := (others => '0');
    --signal normalised_threshold : unsigned(CORRELATION_WIDTH-1 downto 0) := (others => '0');
    signal energy : signed(CORRELATION_WIDTH-1 downto 0) := (others => '0');
begin
    trigger_process : process(clk)
        variable input_i_sq : signed(IQ_WIDTH*2-1 downto 0);
        variable input_q_sq : signed(IQ_WIDTH*2-1 downto 0);
        variable magnitude_sq : unsigned(IQ_WIDTH*2 downto 0);
        variable sum : signed(CORRELATION_WIDTH-1 downto 0);
        variable sum_energy : signed(CORRELATION_WIDTH-1 downto 0);

        constant THRESHOLD_SCALE : unsigned(CORRELATION_WIDTH-1 downto 0) := to_unsigned(1000000000, CORRELATION_WIDTH);
    begin
        if (rising_edge(clk)) then
            input_i_sq := input_i * input_i;
            input_q_sq := input_q * input_q;
            magnitude_sq := resize(unsigned(input_i_sq), magnitude_sq'length) + resize(unsigned(input_q_sq), magnitude_sq'length);

	        shift_reg(0) <= magnitude_sq;
            for i in 1 to BUFFER_LENGTH-1 loop
                shift_reg(i) <= shift_reg(i-1);
            end loop;

            sum := (others => '0');
            sum_energy := (others => '0');
            for i in 0 to BUFFER_LENGTH-1 loop
                if p(i) = to_signed(1, 2) then
                    sum := sum + signed(resize(shift_reg(BUFFER_LENGTH-i-1), sum'length));
                elsif p(i) = to_signed(-1, 2) then
                    sum := sum - signed(resize(shift_reg(BUFFER_LENGTH-i-1), sum'length));
                end if;
                sum_energy := sum_energy + signed(resize(shift_reg(BUFFER_LENGTH-i-1), sum_energy'length));
            end loop;
            correlation <= sum;
            energy <= sum_energy;
        end if;

        --correlation_sq <= unsigned(correlation) * unsigned(correlation);
        --normalised_threshold <= sum_energy * THRESHOLD_SCALE;

        detect <= '1' when (correlation > (energy * 3) srl 2) else '0';

    end process trigger_process;

end Behavioral;

