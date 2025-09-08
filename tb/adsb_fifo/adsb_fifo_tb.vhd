library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;

entity adsb_fifo_tb is
--  port ( );
    generic (runner_cfg : string);
end adsb_fifo_tb;

architecture test of adsb_fifo_tb is
    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

    -- FIFO parameters
    constant FIFO_WIDTH : integer := 16;
    constant FIFO_DEPTH : integer := 4;

    -- Clock and reset.
    signal fifo_clk : std_logic := '0';
    signal fifo_rst : std_logic := '0';

    -- Write side.
    signal fifo_wr_en   : std_logic := '0';
    signal fifo_wr_data : std_logic_vector(FIFO_WIDTH-1 downto 0) := (others => '0');
    signal fifo_full    : std_logic;

    -- Read side.
    signal fifo_rd_en   : std_logic := '0';
    signal fifo_rd_data : std_logic_vector(FIFO_WIDTH-1 downto 0);
    signal fifo_empty   : std_logic;

begin
    clk <= not clk after clk_period / 2;

    uut : entity work.adsb_fifo
        generic map (
            FIFO_WIDTH => FIFO_WIDTH,
            FIFO_DEPTH => FIFO_DEPTH
        )
        port map (
            clk     => clk,
            rst     => fifo_rst,
            wr_en   => fifo_wr_en,
            wr_data => fifo_wr_data,
            full    => fifo_full,
            rd_en   => fifo_rd_en,
            rd_data => fifo_rd_data,
            empty   => fifo_empty
        );

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        report "Hello world!";
        wait for clk_period * 10000;
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;
end test;
