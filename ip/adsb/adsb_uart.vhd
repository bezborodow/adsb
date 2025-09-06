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

    -- UART signals.
    signal uart_tx : std_logic := '1';
    signal uart_vld : std_logic := '0';
    signal uart_rdy : std_logic := '0';
    signal uart_data : std_logic_vector(7 downto 0) := (others => '0');

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

    i_uart_tx : entity work.uart_tx
        generic map (
            CLK_DIV => UART_CLK_DIV
        )
        port map (
            clk => clk,
            vld_i => uart_vld,
            rdy_o => uart_rdy,
            data_i => uart_data,
            tx_o => uart_tx
        );

    i_r <= i_i(RX_IQ_WIDTH-1 downto RX_IQ_WIDTH-IQ_WIDTH);
    q_r <= q_i(RX_IQ_WIDTH-1 downto RX_IQ_WIDTH-IQ_WIDTH);
    d_vld_r <= d_vld_i;
    uart_tx_o <= uart_tx;
    led_o <= led_r;

    main_process : process(clk)
    begin
        if rising_edge(clk) then
            if adsb_detect = '1' then
                -- Turn on LED if a valid ADS-B message was detected.
                -- TODO maybe put this on a timer.
                led_r <= '1';
            end if;

            if adsb_vld = '1' then
                -- Handle valid data.
            end if;

            -- TODO Test UART.
            uart_vld <= '0';
            adsb_rdy <= '0';
            if uart_rdy = '1' and adsb_vld = '1' then
                if uart_timer = UART_TIMER_MAX-1 then
                    uart_data <= X"4D";
                    uart_vld <= '1';
                    uart_timer <= 0;
                    adsb_rdy <= '1';
                else
                    uart_timer <= uart_timer + 1;
                    uart_vld <= '0';
                end if;
            else
                uart_timer <= 0;
            end if;
        end if;
    end process main_process;
end rtl;
