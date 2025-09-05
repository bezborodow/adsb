library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;


entity uart_tx_tb is
--  port ( );
    generic (runner_cfg : string);
end uart_tx_tb;

architecture test of uart_tx_tb is
    signal clk : std_logic := '1';
    constant clk_period : time := 16 ns;

    constant UART_DATA_WIDTH : integer := 8;
    constant UART_CLK_DIV : integer := 533;

    signal uart_vld : std_logic := '0';
    signal uart_rdy : std_logic := '0';
    signal uart_data : std_logic_vector(UART_DATA_WIDTH-1 downto 0) := (others => '0');
    signal uart_tx : std_logic := '1';

begin
    clk <= not clk after clk_period / 2;

    uut : entity work.uart_tx
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

    main : process
    begin
        test_runner_setup(runner, runner_cfg);

        wait for clk_period * UART_CLK_DIV;

        assert uart_rdy = '1' report "Should be ready." severity failure;
        assert uart_tx = '1' report "Should not be transmitting; idle high.";
        uart_data <= X"4D";
        uart_vld <= '1';
        wait for clk_period;

        assert uart_rdy = '1' report "Should be ready." severity failure;
        uart_vld <= '0';
        wait for clk_period;

        assert uart_rdy = '0' report "Should be busy." severity failure;

        wait for clk_period * UART_CLK_DIV;
        wait for clk_period * UART_CLK_DIV;
        wait for clk_period * UART_CLK_DIV;
        wait for clk_period * UART_CLK_DIV;
        wait for clk_period * UART_CLK_DIV;
        wait for clk_period * UART_CLK_DIV;
        wait for clk_period * UART_CLK_DIV;
        wait for clk_period * UART_CLK_DIV;
        wait for clk_period * UART_CLK_DIV;
        wait for clk_period * UART_CLK_DIV;
        wait for clk_period * UART_CLK_DIV;
        wait for clk_period * UART_CLK_DIV;
        wait for clk_period * UART_CLK_DIV;
        wait for clk_period * UART_CLK_DIV;

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;
end test;
