library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_uart is
    generic (
        SAMPLES_PER_PULSEB : integer := 30;
        PREAMBLE_BUFFER_LENGTH : integer := 480;
        ACCUMULATION_LENGTH : integer := 4096;
        UART_CLK_DIV : integer := 521 -- 60_000_000/115200
    );
    port (
        clk : in std_logic;
        d_vld_i : in std_logic; -- In-phase quadrature (IQ) data is valid.
        i_i : in signed(ADC_RX_IQ_WIDTH-1 downto 0); -- In-phase sample.
        q_i : in signed(ADC_RX_IQ_WIDTH-1 downto 0); -- Quadrature sample.
        uart_tx_o : out std_logic; -- UART transmission port.
        led_o : out std_logic -- Activity indicator LED GPIO.
    );
end adsb_uart;

architecture rtl of adsb_uart is
    -- FIFO parameters.
    constant ADSB_FIFO_WIDTH : integer := 177;
    constant ADSB_FIFO_DEPTH : integer := 4;

    -- Clock enable.
    signal ce_c : std_logic := '0';

    -- 16 bit IQ to 12 bit registers.
    signal i_rx_12b_r : iq_t := (others => '0');
    signal q_rx_12b_r : iq_t := (others => '0');

    -- ADSB demodalator and frequency estimator signals.
    signal adsb_detect       : std_logic := '0';
    signal adsb_vld          : std_logic := '0';
    signal adsb_rdy          : std_logic := '0';
    signal adsb_w56          : std_logic := '0';
    signal adsb_data         : std_logic_vector(111 downto 0) := (others => '0');
    signal adsb_re           : signed(31 downto 0) := (others => '0');
    signal adsb_im           : signed(31 downto 0) := (others => '0');
    signal adsb_fifo_wr_data : std_logic_vector(ADSB_FIFO_WIDTH-1 downto 0); -- Holds packed data for the FIFO.

    -- FIFO read side signals.
    signal fifo_rd_data  : std_logic_vector(ADSB_FIFO_WIDTH-1 downto 0);
    signal fifo_rd_vld   : std_logic := '0';
    signal fifo_rd_rdy   : std_logic := '0';

    -- Combinatorial FIFO signals.
    signal fifo_rd_adsb_c : std_logic_vector(111 downto 0);
    signal fifo_rd_re_c   : signed(31 downto 0);
    signal fifo_rd_im_c   : signed(31 downto 0);
    signal fifo_rd_w56_c  : std_logic;

    -- Serialiser signals.
    signal srl_s_vld   : std_logic := '0';
    signal srl_s_last  : std_logic := '0';                  -- Last byte indicator.
    signal srl_s_rdy   : std_logic;
    signal srl_s_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal srl_s_ascii : std_logic := '0';                  -- Convert to ASCII.
    signal srl_s_eom   : std_logic := '0';                  -- End-of-message (newline.)

    -- Encoder signals.
    signal enc_s_vld   : std_logic := '0';
    signal enc_s_rdy   : std_logic;
    signal enc_s_data  : std_logic_vector(7 downto 0) := (others => '0');

    -- UART signals.
    signal uart_tx : std_logic := '1';

    -- Output registers.
    signal led_r : std_logic := '0';

begin
    u_adsb : entity work.adsb
        generic map (
            SAMPLES_PER_PULSEB     => SAMPLES_PER_PULSEB,
            PREAMBLE_BUFFER_LENGTH => PREAMBLE_BUFFER_LENGTH,
            ACCUMULATION_LENGTH    => ACCUMULATION_LENGTH
        )
        port map (
            clk => clk,
            d_vld_i => d_vld_i,
            i_i => i_rx_12b_r,
            q_i => q_rx_12b_r,
            vld_o => adsb_vld,
            detect_o => adsb_detect,
            rdy_i => adsb_rdy,
            data_o => adsb_data,
            w56_o => adsb_w56,
            est_re_o => adsb_re,
            est_im_o => adsb_im
        );

    u_adsb_fifo : entity work.adsb_fifo
        generic map (
            FIFO_WIDTH => ADSB_FIFO_WIDTH,
            FIFO_DEPTH => ADSB_FIFO_DEPTH
        )
        port map (
            clk        => clk,
            ce_i       => ce_c,
            rst        => '0',
            wr_data_i  => adsb_fifo_wr_data, -- This data is packed combinatorially for the FIFO.
            wr_vld_i   => adsb_vld,
            wr_rdy_o   => adsb_rdy,
            rd_data_o  => fifo_rd_data,
            rd_vld_o   => fifo_rd_vld,
            rd_rdy_i   => fifo_rd_rdy
        );

    u_adsb_serialiser : entity work.adsb_serialiser
        port map (
            clk        => clk,
            ce_i       => ce_c,
            m_vld_i    => fifo_rd_vld,
            m_rdy_o    => fifo_rd_rdy,
            m_w56_i    => fifo_rd_w56_c,
            m_data_i   => fifo_rd_adsb_c,
            m_est_re_i => fifo_rd_re_c,
            m_est_im_i => fifo_rd_im_c,
            s_vld_o    => srl_s_vld,
            s_last_o   => srl_s_last,
            s_rdy_i    => srl_s_rdy,
            s_data_o   => srl_s_data,
            s_ascii_o  => srl_s_ascii,
            s_eom_o    => srl_s_eom
        );

    u_uart_tx_enc : entity work.uart_tx_enc
        port map (
            clk => clk,
            ce_i => ce_c,
            m_vld_i => srl_s_vld,
            m_rdy_o => srl_s_rdy,
            m_data_i => srl_s_data,
            m_ascii_i => srl_s_ascii,
            m_eom_i => srl_s_eom,
            s_vld_o => enc_s_vld,
            s_rdy_i => enc_s_rdy,
            s_data_o => enc_s_data
        );

    u_uart_tx : entity work.uart_tx
        generic map (
            CLK_DIV => UART_CLK_DIV
        )
        port map (
            clk => clk,
            ce_i => ce_c,
            vld_i => enc_s_vld,
            rdy_o => enc_s_rdy,
            data_i => enc_s_data,
            tx_o => uart_tx
        );

    -- Clock enable.
    ce_c <= d_vld_i; -- Enable clock upon valid IQ data from the ADC.

    -- Extract 12 bit IQ data from 16 bits of the receive (rx) ADC.
    --
    -- Documentation:
    --
    --     https://wiki.analog.com/resources/fpga/docs/axi_ad9361
    --     https://ez.analog.com/fpga/f/q-a/594383/dynamic-bit-selection-ad9361
    --     https://ez.analog.com/fpga/f/q-a/106589/how-are-the-16-bit-iq-samples-formatted-in-the-hdl-fmcomms3-zedboard
    --
    -- The samples are always 16 bits, regardless of the ADC/DAC data width.
    -- That is the source or destination is intended to handle samples as 16 bits.
    -- In the transmit direction, if the DAC data width is less than 16 bits, the
    -- most significant bits are used. In the receive direction, if the ADC data
    -- width is less than 16 bits, the most significant bits are sign extended.
    i_rx_12b_r <= resize(i_i, IQ_WIDTH);
    q_rx_12b_r <= resize(q_i, IQ_WIDTH);

    -- Combinatorial packing for FIFO write data.
    adsb_fifo_wr_data <= adsb_w56 & adsb_data & std_logic_vector(adsb_re) & std_logic_vector(adsb_im);

    -- Combinatorial unpacking from FIFO read data.
    fifo_rd_w56_c  <= fifo_rd_data(176);
    fifo_rd_adsb_c <= fifo_rd_data(175 downto 64);
    fifo_rd_re_c   <= signed(fifo_rd_data(63 downto 32));
    fifo_rd_im_c   <= signed(fifo_rd_data(31 downto 0));

    -- Drive outputs.
    uart_tx_o <= uart_tx;
    led_o <= led_r;
end rtl;
