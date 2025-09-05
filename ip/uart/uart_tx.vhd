library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_misc.xor_reduce;
use work.adsb_pkg.all;

entity uart_tx is
    generic (
        CLK_DIV : positive := 533;
        DATA_WIDTH : positive := 8
    );
    port (
        clk : in std_logic;
        vld_i : in std_logic;
        rdy_o : out std_logic;
        data_i : in std_logic_vector(DATA_WIDTH-1 downto 0);
        tx_o : out std_logic
    );
end uart_tx;

architecture rtl of uart_tx is

    -- Baud rate timing.
    signal baud_strobe : std_logic := '0';
    signal baud_timer : natural range 0 to CLK_DIV-1 := 0;

    -- Internal registers.
    signal vld_r : std_logic := '0';
    signal rdy_r : std_logic := '1';
    signal data_r : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal tx_r : std_logic := '1';

    -- Shift-out and data signals.
    constant SHIFT_OUT_WIDTH : positive := DATA_WIDTH + 4; -- Start, parity, and 2 stop bits.
    signal shift_out : std_logic_vector(SHIFT_OUT_WIDTH-1 downto 0) := (others => '0');
    signal shift_counter : natural range 0 to SHIFT_OUT_WIDTH-1 := 0;

begin
    vld_r <= vld_i;
    rdy_o <= rdy_r;
    data_r <= data_i;
    tx_o <= tx_r;

    baud_rate_process : process(clk)
    begin
        if rising_edge(clk) then
            if baud_timer = CLK_DIV-1 then
                baud_timer <= 0;
                baud_strobe <= '1';
            else
                baud_strobe <= '0';
                baud_timer <= baud_timer + 1;
            end if;
        end if;
    end process baud_rate_process;

    -- Receive more data when ready and valid.
    tx_process : process(clk)
        variable parity : std_logic := '0';
    begin
        if rising_edge(clk) then
            if rdy_r = '1' and vld_r = '1' then
                parity := xor_reduce(data_r);
                shift_out <= "11" & parity & data_r & "0";
                rdy_r <= '0';
                shift_counter <= 0;
            end if;

            if baud_strobe = '1' and rdy_r = '0' then
                if shift_counter = SHIFT_OUT_WIDTH-1 then
                    rdy_r <= '1';
                else
                    shift_counter <= shift_counter + 1;
                end if;

                tx_r <= shift_out(0);
                shift_out <= std_logic_vector(shift_right(unsigned(shift_out), 1));

                -- 11 stop
                -- 10 stop
                -- 9 parity
                -- 8 D7
                -- 7 
                -- 6
                -- 5
                -- 4
                -- 3
                -- 2
                -- 1 D0
                -- 0 start
            end if;
        end if;
    end process tx_process;
end rtl;
