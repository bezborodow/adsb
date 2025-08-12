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

    -- Q15 format threshold = 0.8 → 0.8 * 2^15 ≈ 26214
    constant THRESHOLD_Q15 : integer := 26214;


    type iq_buffer_t is array (natural range <>) of unsigned(IQ_WIDTH*2 downto 0);
    signal shift_reg : iq_buffer_t(0 to BUFFER_LENGTH-1) := (others => (others => '0'));

    signal correlation : signed((IQ_WIDTH*2)+integer(ceil(log2(real(BUFFER_LENGTH))))-1 downto 0) := (others => '0');
begin
    trigger_process : process(clk)
        variable input_i_sq : signed(IQ_WIDTH*2-1 downto 0);
        variable input_q_sq : signed(IQ_WIDTH*2-1 downto 0);
        variable magnitude_sq : unsigned(IQ_WIDTH*2 downto 0);
        variable sum : signed((IQ_WIDTH*2)+integer(ceil(log2(real(BUFFER_LENGTH))))-1 downto 0);
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
            for i in 0 to BUFFER_LENGTH-1 loop
                if p(i) = to_signed(1, 2) then
                    sum := sum + signed(resize(shift_reg(BUFFER_LENGTH-i-1), sum'length));
                elsif p(i) = to_signed(-1, 2) then
                    sum := sum - signed(resize(shift_reg(BUFFER_LENGTH-i-1), sum'length));
                end if;
            end loop;
            correlation <= sum;
        end if;

        -- multiply both correlation and energy by scaling factor before comparing
        --detect <= '1' when (correlation > to_signed(THRESHOLD_Q15, corr'length) * signed(energy)) else '0';
        detect <= '1' when (correlation > to_signed(THRESHOLD_Q15, correlation'length)) else '0';

    end process trigger_process;


    --C <= C + resize(x, C'length) * resize(p(sample_idx), C'length);
end Behavioral;

