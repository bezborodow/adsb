library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.uart_pkg.all;

entity adsb_serialiser is
    port (
        clk : in std_logic;
        ce_i : in std_logic;

        -- Master (ADSB.)
        m_vld_i : in std_logic;
        m_rdy_o : out std_logic;
        m_data_i : in std_logic_vector(111 downto 0); -- The ADS-B message.
        m_w56_i : in std_logic; -- If high, the ADS-B message is a short 56 bit message instead of 112 bit.
        m_est_re_i : in signed(31 downto 0); -- Real phasor of frequency estimate.
        m_est_im_i : in signed(31 downto 0); -- Imaginary part of the phasor.

        -- Slave (serialised data.)
        s_vld_o : out std_logic;
        s_last_o : out std_logic;
        s_rdy_i : in std_logic;
        s_data_o : out std_logic_vector(7 downto 0); -- The numeric data to send to the encoder.
        s_ascii_o : out std_logic; -- Determines if the encoder should convert the number to ASCII (always high.)
        s_eom_o : out std_logic -- Tell the encoder to append a newline to indicate end of message.
    );
end adsb_serialiser;

architecture rtl of adsb_serialiser is
    constant MAX_MESSAGE_BYTES : positive := (112 + 64) / 8;
    signal serial_buffer : uart_byte_array_t(0 to MAX_MESSAGE_BYTES-1) := (others => (others => '0'));
    signal buffer_valid : std_logic := '0'; -- Master process indicates that valid data ready to send.
    signal buffer_ready : std_logic := '1'; -- Slave process is ready to receive data to send (buffer not in use.)
    signal buffer_index : integer range 0 to MAX_MESSAGE_BYTES-1 := 0;
    signal message_length : positive range 1 to MAX_MESSAGE_BYTES := MAX_MESSAGE_BYTES;
    signal m_rdy_c : std_logic := '0';
    signal s_vld_c : std_logic := '0';
    signal s_last_c : std_logic := '0';
    signal s_data_c : std_logic_vector(7 downto 0) := (others => '0');
begin
    s_ascii_o <= '1';
    m_rdy_c <= '1' when buffer_valid = '0' and buffer_ready = '1' else '0';
    m_rdy_o <= m_rdy_c;
    s_vld_o <= s_vld_c;
    s_last_o <= s_last_c;
    s_eom_o <= s_last_c; -- Use same signal last for EOM.
    s_data_o <= s_data_c when s_vld_c = '1' else (others => '0');

    master_process : process(clk) is
        variable adsb_length : positive range 56 to 112 := 112;
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                if m_vld_i = '1' and m_rdy_c = '1' then
                    -- Determine length of ADS-B message in bits.
                    if m_w56_i = '1' then
                        adsb_length := 56;
                    else
                        adsb_length := 112;
                    end if;

                    -- Insert ADS-B message into the serial buffer.
                    if m_w56_i = '1' then
                        for i in 0 to 6 loop  -- 56/8 - 1
                            serial_buffer(i) <= m_data_i(55 - i*8 downto 48 - i*8);
                        end loop;
                    else
                        for i in 0 to 13 loop -- 112/8 - 1
                            serial_buffer(i) <= m_data_i(111 - i*8 downto 104 - i*8);
                        end loop;
                    end if;

                    -- Append real part of phasor.
                    serial_buffer(adsb_length/8 + 0) <= std_logic_vector(m_est_re_i(31 downto 24));
                    serial_buffer(adsb_length/8 + 1) <= std_logic_vector(m_est_re_i(23 downto 16));
                    serial_buffer(adsb_length/8 + 2) <= std_logic_vector(m_est_re_i(15 downto 8));
                    serial_buffer(adsb_length/8 + 3) <= std_logic_vector(m_est_re_i(7 downto 0));

                    -- Append imaginary part of phasor.
                    serial_buffer(adsb_length/8 + 4) <= std_logic_vector(m_est_im_i(31 downto 24));
                    serial_buffer(adsb_length/8 + 5) <= std_logic_vector(m_est_im_i(23 downto 16));
                    serial_buffer(adsb_length/8 + 6) <= std_logic_vector(m_est_im_i(15 downto 8));
                    serial_buffer(adsb_length/8 + 7) <= std_logic_vector(m_est_im_i(7 downto 0));

                    -- Pass to serialiser process.
                    message_length <= (adsb_length + 64) / 8;
                    buffer_valid <= '1';
                end if;

                if buffer_valid = '1' and buffer_ready = '1' then
                    -- Finished sending to slave. Serialiser is empty. Ready to accept more data.
                    buffer_valid <= '0';
                end if;
            end if;
        end if;
    end process master_process;

    slave_process : process(clk)
        variable slave_valid_n : std_logic;
        variable buffer_index_n : integer range 0 to MAX_MESSAGE_BYTES-1;
        variable buffer_ready_n : std_logic;
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                slave_valid_n := s_vld_c;
                buffer_index_n := buffer_index;
                buffer_ready_n := buffer_ready;

                -- If currently sending data from the buffer.
                if buffer_ready_n = '0' then
                    -- Increment index only if downstream is ready.
                    if s_rdy_i = '1' then
                        if buffer_index_n = message_length-1 then
                            buffer_ready_n := '1'; -- Return ownership to master process.
                            buffer_index_n := 0; -- Reset buffer index.
                            slave_valid_n := '0'; -- Cease sending data.
                        else
                            buffer_index_n := buffer_index_n + 1;
                        end if;
                    end if;

                -- Accept new data from the master process that was put into the buffer.
                elsif buffer_valid = '1' and buffer_ready_n = '1' then
                    -- Put out the first byte of data.
                    buffer_index_n := 0;
                    slave_valid_n := '1';

                    -- Take ownership of the buffer.
                    -- Lowering the ready flag means that the slave process is busy iterating
                    -- over the buffer, serialising it, and sending bytes to the slave.
                    buffer_ready_n := '0'; 
                end if;

                -- Set signals for next cycle.
                buffer_index <= buffer_index_n;
                buffer_ready <= buffer_ready_n;
                s_vld_c <= slave_valid_n;
                s_data_c <= serial_buffer(buffer_index_n);
                if buffer_index_n = message_length-1 then
                    s_last_c <= '1'; -- Assert last signals on the last byte.
                else
                    s_last_c <= '0';
                end if;
            end if;
        end if;
    end process slave_process;

end rtl;
