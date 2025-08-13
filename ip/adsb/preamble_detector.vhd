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

    -- Where each pulse in the preamble starts.
    constant PREAMBLE_POS : integer_vector := (0, 2, 7, 9);

    -- Energy in each pulse window.
    constant WINDOW_WIDTH : integer := (IQ_WIDTH*2) + integer(ceil(log2(real(SAMPLES_PER_SYMBOL))));
    type symbol_energy_t is array (0 to PREAMBLE_POS'length-1) of unsigned(WINDOW_WIDTH-1 downto 0);
    signal sym_energy : symbol_energy_t := (others => (others => '0'));

    type iq_buffer_t is array (natural range <>) of unsigned(IQ_WIDTH*2 downto 0);
    signal shift_reg : iq_buffer_t(0 to BUFFER_LENGTH-1) := (others => (others => '0'));

    signal correlation : signed(CORRELATION_WIDTH-1 downto 0) := (others => '0');
    --signal correlation_sq : unsigned(2*CORRELATION_WIDTH-1 downto 0) := (others => '0');
    --signal normalised_threshold : unsigned(CORRELATION_WIDTH-1 downto 0) := (others => '0');
    signal energy : unsigned(CORRELATION_WIDTH-1 downto 0) := (others => '0');
begin
    trigger_process : process(clk)
        variable input_i_sq : signed(IQ_WIDTH*2-1 downto 0);
        variable input_q_sq : signed(IQ_WIDTH*2-1 downto 0);
        variable magnitude_sq : unsigned(IQ_WIDTH*2 downto 0);
        variable sum_energy : unsigned(CORRELATION_WIDTH-1 downto 0);

        variable tmp_sym : symbol_energy_t;
        variable idx_sym : integer;

        constant THRESHOLD_SCALE : unsigned(CORRELATION_WIDTH-1 downto 0) := to_unsigned(1000000000, CORRELATION_WIDTH);
    begin
        if (rising_edge(clk)) then
            input_i_sq := input_i * input_i;
            input_q_sq := input_q * input_q;
            magnitude_sq := resize(unsigned(input_i_sq), magnitude_sq'length) + resize(unsigned(input_q_sq), magnitude_sq'length);

            -- Append most recently arrived sample onto the end of the shift register.
	        shift_reg(BUFFER_LENGTH-1) <= magnitude_sq;
            for i in 0 to BUFFER_LENGTH-2 loop
                shift_reg(i) <= shift_reg(i+1);
            end loop;

            -- zero local accumulators
            for j in 0 to PREAMBLE_POS'length-1 loop
                tmp_sym(j) := (others => '0');
            end loop;

            -- sum each symbol bin from the shift_reg. Assumes shift_reg(0) is most recent sample.
            for i in 0 to PREAMBLE_POS'length-1 loop
                for ii in 0 to SAMPLES_PER_SYMBOL-1 loop
                    idx_sym := PREAMBLE_POS(i)*SAMPLES_PER_SYMBOL + ii;
                    tmp_sym(i) := tmp_sym(i) + resize(shift_reg(idx_sym), tmp_sym(i)'length);
                end loop;
            end loop;

            -- write back to signals (or keep as variables)
            for j in 0 to PREAMBLE_POS'length-1 loop
                sym_energy(j) <= tmp_sym(j);
            end loop;

            sum_energy := (others => '0');
            for i in 0 to BUFFER_LENGTH-1 loop
                sum_energy := sum_energy + resize(shift_reg(BUFFER_LENGTH-i-1), sum_energy'length);
            end loop;
            energy <= sum_energy;
        end if;

    end process trigger_process;

    detect_process : process(clk)
        variable all_thresholds_ok : boolean := false;
        variable threshold : unsigned(energy'length-1 downto 0);
        --variable energy_u : unsigned(sym_energy(0)'length-1 downto 0);
    begin
        threshold := resize((energy * to_unsigned(3, energy'length+2)) srl 4, energy'length);

        if (rising_edge(clk)) then
            all_thresholds_ok := true;
            for i in PREAMBLE_POS'range loop
                if resize(sym_energy(i), energy'length) <= threshold then
                    all_thresholds_ok := false;
                end if;
            end loop;

            detect <= '1' when all_thresholds_ok else '0';
        end if;
    end process detect_process;

end Behavioral;

