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
        i_i : in signed(RX_IQ_WIDTH-1 downto 0);
        q_i : in signed(RX_IQ_WIDTH-1 downto 0);
        uart_tx_o : out std_logic
    );
end adsb_uart;

architecture rtl of adsb_uart is
    signal uart_tx_r : std_logic := '0';
begin
    uart_tx_o <= uart_tx_r;

    main_process : process(clk)
    begin
        if rising_edge(clk) then
            uart_tx_r <= i_i(0) xor q_i(0);
        end if;
    end process main_process;
end rtl;

