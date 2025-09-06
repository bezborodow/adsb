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
    --constant SHIFT_OUT_WIDTH : positive := DATA_WIDTH + 3; -- Parity, and 2 stop bits.
    constant SHIFT_OUT_WIDTH : positive := DATA_WIDTH + 2; -- Append two stop bits.
    signal shift_out : std_logic_vector(SHIFT_OUT_WIDTH-1 downto 0) := (others => '0');
    signal shift_counter : natural range 0 to SHIFT_OUT_WIDTH-1 := 0;

    -- Handshake signals.
    signal pending : std_logic := '0'; -- A valid data has been accepted and will begin transmission on the next baud strobe.
    signal sending : std_logic := '0'; -- Currently sending data.
    signal queued_data : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

begin
    vld_r <= vld_i;
    rdy_o <= rdy_r;
    data_r <= data_i;
    tx_o <= tx_r;

    -- Combinatorial logic.
    rdy_r <= '1' when (pending = '0' and sending = '0') else '0';

    -- Set up the baud rate as a strobe controlled by a timer.
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
    data_handshake_process : process(clk)
    begin
        if rising_edge(clk) then
            if rdy_r = '1' and vld_r = '1' then
                queued_data <= data_r;
                pending <= '1';
            end if;

            -- Transmission process should acknowledge the queued data and begin sending.
            if pending = '1' and sending = '1' then
                pending <= '0';
            end if;
        end if;
    end process data_handshake_process;


    -- Transmit data; shift out of the register.
    -- Each symbol starts that the beginning of the baud strobe.
    tx_process : process(clk)
        --variable parity : std_logic := '0';
    begin
        if rising_edge(clk) then
            if baud_strobe = '1' then
                -- Start of a new frame.
                -- Send start bit and read data and stop bits into shift register.
                if pending = '1' and sending = '0' then
                    shift_counter <= 0;
                    sending <= '1'; -- Let the data handshake process know that data is being sent.
                    --parity := xor_reduce(queued_data);
                    --shift_out <= "11" & parity & queued_data;
                    shift_out <= "11" & queued_data;
                    tx_r <= '0'; -- Start bit is logic low.
                end if;

                -- Increment counter until finished.
                if pending = '0' and sending = '1' then
                    if shift_counter = SHIFT_OUT_WIDTH-1 then
                        sending <= '0';
                    else
                        shift_counter <= shift_counter + 1;
                    end if;

                    tx_r <= shift_out(0);
                    shift_out <= std_logic_vector(shift_right(unsigned(shift_out), 1));
                end if;
            end if;
        end if;
    end process tx_process;

    -- 10 stop
    -- 9 stop
    -- 8 D7
    -- 7 
    -- 6
    -- 5
    -- 4
    -- 3
    -- 2
    -- 1 D0
    -- 0 start
end rtl;
