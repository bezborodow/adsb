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
    generic (
        DATA_WIDTH : positive := 8
    );
    port (
        clk : in std_logic;

        -- Master.
        m_vld_i : in std_logic;
        m_rdy_o : out std_logic;
        m_data_i : in std_logic_vector(DATA_WIDTH-1 downto 0);
        m_ascii_i : in std_logic; -- Convert to ASCII.
        m_eom_i : in std_logic; -- End of message (EOM.)

        -- UART side (slave.)
        s_vld_o : out std_logic;
        s_rdy_i : in std_logic;
        s_data_o : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end uart_tx_enc;

architecture rtl of uart_tx_enc is
    constant MAX_FRAMES : positive := 3; -- Maximum number of frames is two ASCII octets terminated with a newline.

    -- Internal registers.
    signal m_vld_r : std_logic := '0';
    signal m_rdy_r : std_logic := '1';
    signal m_data_r : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal m_ascii_r : std_logic := '0';
    signal m_eom_r : std_logic := '0';
    signal s_vld_r : std_logic := '0';
    signal s_rdy_r : std_logic := '0';
    signal s_data_r : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    -- Buffer signals.
    type frame_buffer_t is array (natural range <>) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal frame_buffer : frame_buffer_t(0 to MAX_FRAMES-1) := (others => (others => '0'));
    signal buffer_ready : std_logic := '1';

begin
    -- Internal registers.
    m_vld_r <= m_vld_i;
    m_rdy_o <= m_rdy_r;
    m_data_r <= m_data_i;
    m_ascii_r <= m_ascii_i;
    m_eom_r <= m_eom_i;
    s_vld_o <= s_vld_r;
    s_rdy_r <= s_rdy_i;
    s_data_o <= s_data_r;

    buffer_encoder_process : process(clk)
    begin
        if rising_edge(clk) then
            if buffer_ready = '1' then
            end if;
        end if;
    end process buffer_encoder_process;

    sender_process : process(clk)
    begin
        if rising_edge(clk) then
        end if;
    end process sender_process;
end rtl;
