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
        PREAMBLE_POSITION : adsb_int_array_t := ADSB_PREAMBLE_POSITION
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

    signal adsb_w56 : std_logic := '0';
    signal adsb_data : std_logic_vector(111 downto 0) := (others => '0');
    signal i_r : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal q_r : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal d_vld_r : std_logic := '0';
    signal adsb_vld: std_logic := '0';
    signal adsb_detect: std_logic := '0';
    signal led_r : std_logic := '0';
    signal uart_tx_r : std_logic := '1';
    signal adsb_re : signed(31 downto 0) := (others => '0');
    signal adsb_im : signed(31 downto 0) := (others => '0');

begin
    adsb_sys: entity work.adsb port map (
        clk => clk,
        d_vld_i => d_vld_r,
        i_i => i_r,
        q_i => q_r,
        vld_o => adsb_vld,
        detect_o => adsb_detect,
        rdy_i => '0',
        data_o => adsb_data,
        w56_o => adsb_w56,
        est_re_o => adsb_re,
        est_im_o => adsb_im
    );

    i_r <= i_i(RX_IQ_WIDTH-1 downto RX_IQ_WIDTH-IQ_WIDTH);
    q_r <= q_i(RX_IQ_WIDTH-1 downto RX_IQ_WIDTH-IQ_WIDTH);
    d_vld_r <= d_vld_i;
    uart_tx_o <= uart_tx_r;
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
                -- TODO Random stuff on UART for fun.
                if adsb_w56 = '1' and adsb_re(0) = '1' and adsb_im(0) = '0' then
                    uart_tx_r <= '0';
                end if;
            end if;
        end if;
    end process main_process;
end rtl;
