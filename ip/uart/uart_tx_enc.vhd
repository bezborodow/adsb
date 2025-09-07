library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.uart_pkg.all;

-- The UART transmitter encoder sends out a byte as either a single
-- UART frame or as two frames converted into ASCII hexadecimal
-- character codes. The sequence is optionally terminated by another
-- frame representing an ASCII newline when the end of message (EOM)
-- flag is asserted.
--
-- The purpose of this is to allow binary data to be sent as text
-- to a serial teletype (tty) terminal with each message terminated
-- by newlines.
entity uart_tx_enc is
    port (
        clk : in std_logic;

        -- Master.
        m_vld_i : in std_logic;
        m_rdy_o : out std_logic;
        m_data_i : in std_logic_vector(7 downto 0);
        m_ascii_i : in std_logic; -- Convert to ASCII.
        m_eom_i : in std_logic; -- End of message (EOM.)

        -- UART side (slave.)
        s_vld_o : out std_logic;
        s_rdy_i : in std_logic;
        s_data_o : out std_logic_vector(7 downto 0)
    );
end uart_tx_enc;

architecture rtl of uart_tx_enc is
    constant MAX_FRAMES : positive := 3; -- Maximum number of frames is two ASCII octets terminated with a newline.
    constant ASCII_NEWLINE : std_logic_vector(7 downto 0) := x"0A";

    -- Combinatorial internal signals.
    signal m_vld_c : std_logic := '0';
    signal m_rdy_c : std_logic := '1';
    signal m_data_c : std_logic_vector(7 downto 0) := (others => '0');
    signal m_ascii_c : std_logic := '0';
    signal m_eom_c : std_logic := '0';
    signal s_vld_c : std_logic := '0';
    signal s_rdy_c : std_logic := '0';
    signal s_data_c : std_logic_vector(7 downto 0) := (others => '0');

    -- Buffer signals.
    signal encoder_buffer : uart_byte_array_t(0 to MAX_FRAMES-1) := (others => (others => '0'));
    signal sender_buffer : uart_byte_array_t(0 to MAX_FRAMES-1) := (others => (others => '0'));
    signal buffer_valid : std_logic := '0';
    signal buffer_ready : std_logic := '1';

begin
    -- Internal staging/combinatorial signals.
    m_vld_c <= m_vld_i;
    m_rdy_o <= m_rdy_c;
    m_data_c <= m_data_i;
    m_ascii_c <= m_ascii_i;
    m_eom_c <= m_eom_i;
    s_vld_o <= s_vld_c;
    s_rdy_c <= s_rdy_i;
    s_data_o <= s_data_c;

    s_data_c <= sender_buffer(0);

    -- The encoder converts data into ASCII and stores it in the frame buffer.
    encoder_process : process(clk)
    begin
        if rising_edge(clk) then
            if buffer_valid = '1' and buffer_ready = '1' then
                buffer_valid <= '0';
                m_rdy_c <= '1';
                encoder_buffer <= (others => x"00");
            end if;

            if m_vld_c = '1' and m_rdy_c = '1' then
                -- Accept new data.
                if m_ascii_c = '1' then
                    -- ASCII mode.
                    encoder_buffer(0) <= uart_ascii_hex(m_data_c(7 downto 4));
                    encoder_buffer(1) <= uart_ascii_hex(m_data_c(3 downto 0));
                    if m_eom_c = '1' then
                        encoder_buffer(2) <= ASCII_NEWLINE;
                    else
                        encoder_buffer(2) <= x"00";
                    end if;
                else
                    -- Binary mode.
                    encoder_buffer(0) <= m_data_c;
                    if m_eom_c = '1' then
                        encoder_buffer(1) <= ASCII_NEWLINE;
                    else
                        encoder_buffer(1) <= x"00";
                    end if;
                    encoder_buffer(2) <= x"00";
                end if;
                buffer_valid <= '1';

                -- If the sender is busy, then the buffer contents will not be accepted,
                -- so need to delay the pipeline.
                if buffer_ready = '0' then
                    m_rdy_c <= '0';
                end if;

                if encoder_buffer(1) /= x"00" and m_vld_c = '1' then
                    m_rdy_c <= '0';
                end if;
            end if;
        end if;
    end process encoder_process;

    -- The sender reads from the buffer and passes it to the UART transmitter slave.
    sender_process : process(clk)
    begin
        if rising_edge(clk) then
            if s_vld_c = '1' and s_rdy_c = '1' then
                if sender_buffer(1) = x"00" then
                    s_vld_c <= '0';
                    sender_buffer(0) <= x"00";
                    buffer_ready <= '1';
                else
                    sender_buffer(0) <= sender_buffer(1);
                    sender_buffer(1) <= sender_buffer(2);
                    sender_buffer(2) <= x"00";
                end if;
            end if;

            -- Accept data from the encoder buffer.
            if buffer_valid = '1' and buffer_ready = '1' then
                sender_buffer <= encoder_buffer;
                s_vld_c <= '1';

                -- The buffer will be available on the next cycle if the slave is
                -- ready and the buffer will be empty afterwards. Or if the buffer
                -- is already empty.
                if (s_rdy_c = '1' and encoder_buffer(1) = x"00") then
                    buffer_ready <= '1';
                else
                    buffer_ready <= '0';
                end if;
            end if;
        end if;
    end process sender_process;
end rtl;
