library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_uart is
    generic (
        RX_IQ_WIDTH : integer := 16;
        IQ_WIDTH : integer := ADSB_IQ_WIDTH;
        SAMPLES_PER_SYMBOL : integer := ADSB_SAMPLES_PER_SYMBOL;
        PREAMBLE_BUFFER_LENGTH : integer := ADSB_PREAMBLE_BUFFER_LENGTH;
        PREAMBLE_POSITION1 : integer := 61;
        PREAMBLE_POSITION2 : integer := 215;
        PREAMBLE_POSITION3 : integer := 276;
        ACCUMULATION_LENGTH : integer := 4096;
        UART_CLK_DIV : integer := 533
    );
    port (
        clk : in std_logic;
        d_vld_i : in std_logic; -- In-phase quadrature (IQ) data is valid.
        i_i : in signed(RX_IQ_WIDTH-1 downto 0); -- In-phase sample.
        q_i : in signed(RX_IQ_WIDTH-1 downto 0); -- Quadrature sample.
        uart_tx_o : out std_logic; -- UART transmission port.
        led_o : out std_logic -- Activity indicator LED GPIO.
    );
end adsb_uart;

architecture rtl of adsb_uart is
    -- FIFO parameters.
    constant ADSB_FIFO_WIDTH : integer := 177;
    constant ADSB_FIFO_DEPTH : integer := 4;

    -- Internal registers.
    signal i_r : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal q_r : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal d_vld_r : std_logic := '0';
    signal led_r : std_logic := '0';

    -- ADSB demodalator and frequency estimator signals.
    signal adsb_detect: std_logic := '0';
    signal adsb_vld: std_logic := '0';
    signal adsb_rdy: std_logic := '0';
    signal adsb_w56 : std_logic := '0';
    signal adsb_data : std_logic_vector(111 downto 0) := (others => '0');
    signal adsb_re : signed(31 downto 0) := (others => '0');
    signal adsb_im : signed(31 downto 0) := (others => '0');

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
    --signal uart_vld : std_logic := '0';
    --signal uart_rdy : std_logic := '0';
    --signal uart_data : std_logic_vector(7 downto 0) := (others => '0');
    signal uart_tx : std_logic := '1';

    -- TODO Test signals.
    constant UART_TIMER_MAX : positive := 100000;
    signal uart_timer : natural range 0 to UART_TIMER_MAX-1 := UART_TIMER_MAX-1;

begin
    i_adsb : entity work.adsb
        generic map (
            SAMPLES_PER_SYMBOL     => SAMPLES_PER_SYMBOL,
            IQ_WIDTH               => IQ_WIDTH,
            PREAMBLE_BUFFER_LENGTH => PREAMBLE_BUFFER_LENGTH,
            PREAMBLE_POSITION1     => PREAMBLE_POSITION1,
            PREAMBLE_POSITION2     => PREAMBLE_POSITION2,
            PREAMBLE_POSITION3     => PREAMBLE_POSITION3,
            ACCUMULATION_LENGTH    => ACCUMULATION_LENGTH
        )
        port map (
            clk => clk,
            d_vld_i => d_vld_r,
            i_i => i_r,
            q_i => q_r,
            vld_o => adsb_vld,
            detect_o => adsb_detect,
            rdy_i => adsb_rdy,
            data_o => adsb_data,
            w56_o => adsb_w56,
            est_re_o => adsb_re,
            est_im_o => adsb_im
        );

    i_adsb_fifo : entity work.adsb_fifo
        generic map (
            FIFO_WIDTH => ADSB_FIFO_WIDTH,
            FIFO_DEPTH => ADSB_FIFO_DEPTH
        )
        port map (
            clk        => clk,
            rst        => '0',
            wr_data_i  => adsb_w56 & adsb_data & std_logic_vector(adsb_re) & std_logic_vector(adsb_im),
            wr_vld_i   => adsb_vld,
            wr_rdy_o   => adsb_rdy,
            rd_data_o  => fifo_rd_data,
            rd_vld_o   => fifo_rd_vld,
            rd_rdy_i   => fifo_rd_rdy
        );

    i_adsb_serialiser : entity work.adsb_serialiser
        port map (
            clk        => clk,
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

    i_uart_tx_enc : entity work.uart_tx_enc
        port map (
            clk => clk,
            m_vld_i => srl_s_vld,
            m_rdy_o => srl_s_rdy,
            m_data_i => srl_s_data,
            m_ascii_i => srl_s_ascii,
            m_eom_i => srl_s_eom,
            s_vld_o => enc_s_vld,
            s_rdy_i => enc_s_rdy,
            s_data_o => enc_s_data
        );

    i_uart_tx : entity work.uart_tx
        generic map (
            CLK_DIV => UART_CLK_DIV
        )
        port map (
            clk => clk,
            vld_i => enc_s_vld,
            rdy_o => enc_s_rdy,
            data_i => enc_s_data,
            tx_o => uart_tx
        );

    i_r <= i_i(RX_IQ_WIDTH-1 downto RX_IQ_WIDTH-IQ_WIDTH);
    q_r <= q_i(RX_IQ_WIDTH-1 downto RX_IQ_WIDTH-IQ_WIDTH);
    d_vld_r <= d_vld_i;
    uart_tx_o <= uart_tx;
    led_o <= led_r;

    -- Combinatorial unpacking from FIFO read data.
    fifo_rd_w56_c  <= fifo_rd_data(176);
    fifo_rd_re_c   <= signed(fifo_rd_data(63 downto 32));
    fifo_rd_im_c   <= signed(fifo_rd_data(31 downto 0));
    fifo_rd_adsb_c <= fifo_rd_data(175 downto 64);

    main_process : process(clk)
    begin
        if rising_edge(clk) then
            if adsb_detect = '1' then
                -- Turn on LED if a valid ADS-B message was detected.
                -- TODO maybe put this on a timer.
                led_r <= '1';
            end if;
        end if;
    end process main_process;
end rtl;
