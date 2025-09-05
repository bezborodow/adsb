library ieee;
use ieee.std_logic_1164.all;

use ieee.numeric_std.all;
use ieee.math_real.all;

entity adsb_uart is
    generic (
        RX_IQ_WIDTH : integer := 16;
        IQ_WIDTH : integer := 12
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

    signal uart_tx_r : std_logic := '0';
    signal adsb_w56 : std_logic := '0';
    signal adsb_data : std_logic_vector(111 downto 0) := (others => '0');
    signal i_r : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal q_r : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal d_vld_r : std_logic := '0';

begin
    adsb_sys: entity work.adsb port map (
        clk => clk,
        d_vld_i => d_vld_r,
        i_i => i_r,
        q_i => q_r,
        vld_o => uart_tx_r,
        rdy_i => '0',
        data_o => adsb_data,
        w56_o => adsb_w56
    );

    d_vld_r <= d_vld_i;

    i_r <= i_i(RX_IQ_WIDTH-1 downto RX_IQ_WIDTH-IQ_WIDTH);
    q_r <= q_i(RX_IQ_WIDTH-1 downto RX_IQ_WIDTH-IQ_WIDTH);

    uart_tx_o <= uart_tx_r;

    main_process : process(clk)
    begin
        if rising_edge(clk) then
        end if;
    end process main_process;
end rtl;
